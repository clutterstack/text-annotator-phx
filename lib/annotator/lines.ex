defmodule Annotator.Lines do
  @moduledoc """
  The Lines context with simplified chunk handling.
  """

  import Ecto.Query
  alias Annotator.Repo
  alias Annotator.Lines.{Line, Collection, Chunk}
  require Logger

  @doc """
  Gets a collection with its associated lines and their associated
  chunks preloaded.
  Lines will be ordered by line number.
  """
  def get_collection_with_assocs(id) do
    Collection
    |> Repo.get(id)
    |> case do
      nil ->
        nil

      collection ->
        collection
        |> Repo.preload(
          # Preload the collection's associated lines, and sort them;
          # for each line preload its chunk. Now th
          lines: {
            from(l in Line,
              order_by: l.line_number
            ),
            :chunk
          }
        )
    end
  end

  @doc """
  Appends a new chunk to a collection.
  """
  def append_chunk(collection_id) do
    new_line_number = get_max_line_number(collection_id) + 1

    Repo.transaction(fn ->
      # Create a chunk
      {:ok, chunk} =
        create_chunk(
          collection_id,
          new_line_number,
          new_line_number,
          ""
        )

      Logger.info("created a new empty chunk to put a new line in: id #{chunk.id}")
      # Create the line
      %Line{}
      |> Line.changeset(%{
        collection_id: collection_id,
        chunk_id: chunk.id,
        line_number: new_line_number
      })
      |> Repo.insert()
    end)
  end

  @doc """
  Updates a chunk's content. Handles renumbering of lines . Returns {:ok, collection} on success or {:error, reason} on failure.
  """
  def update_content(collection_id, chunk_id, content) do
    content_lines = String.split(content, "\n")
    Logger.info("in update_content -- is chunk_id a string? #{is_binary(chunk_id)}")

    ## get chunk by its ID
    chunk = Repo.get!(Chunk, chunk_id)

    # Set up some variables to use
    {start_line, end_line} = {chunk.start_line, chunk.end_line}
    old_chunk_length = end_line - start_line + 1
    # list won't be very long, but fwiw length is an O(n) operation
    offset = length(content_lines) - old_chunk_length

    Logger.info(
      "new length is #{length(content_lines)}, old length was #{old_chunk_length}, and so offset is #{offset}."
    )

    ## In one transaction: update all affected line numbers and
    ## change chunk boundaries

    Repo.transaction(fn ->
      # Delete all lines currently in chunk
      Logger.info("Delete all lines previously in the chunk")

      from(l in Line,
        where:
          l.collection_id == ^collection_id and
            l.chunk_id == ^chunk_id
      )
      |> Repo.delete_all()

      Logger.info("Shift line numbers on all lines after #{end_line}")
      # Shift line numbers on all lines beyond the original end_line of this chunk
      from(l in Line,
        where: l.collection_id == ^collection_id and l.line_number > ^end_line
      )
      |> Repo.update_all(inc: [line_number: offset])

      # Insert new lines into this chunk
      # Repo.insert_all doesn't autogenerate UUIDs (fine; we're reusing one)
      # or timestamps (so we'll do those manually)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      new_lines =
        content_lines
        |> Enum.with_index(start_line)
        |> Enum.map(fn {content, idx} ->
          %{
            collection_id: collection_id,
            line_number: idx,
            content: content,
            chunk_id: chunk_id,
            inserted_at: now,
            updated_at: now
          }
        end)

      {_, _inserted_lines} = Repo.insert_all(Line, new_lines, returning: true)

      # Update original chunk's end_line
      chunk
      |> Chunk.changeset(%{"end_line" => end_line + offset})
      |> Repo.update()

      ## Update start_line and end_line of every other chunk with c.start_line >= end_line.
      from(c in Chunk,
        # if content is only one line, the original chunk could get caught up in this, so exclude it explicitly
        where:
          c.collection_id == ^collection_id and
            c.start_line >= ^end_line and
            c.id != ^chunk_id
      )
      |> Repo.update_all(inc: [start_line: offset, end_line: offset])
    end)

    # end of the transaction fn
    {:ok, get_collection_with_assocs(collection_id)}
  end

  def update_chunk_note(chunk, note) do
    {:ok, updated_chunk} =
      chunk
      |> Chunk.changeset(%{
        "note" => note
      })
      |> Repo.update()

    {:ok, updated_chunk}
  end

  def update_note_by_id(chunk_id, note) do
    chunk = Repo.get_by(Chunk, id: chunk_id)
    update_chunk_note(chunk, note)
  end

  @doc """
  Places the given line range into its own chunk.
  Ensures the given line range is a single chunk, handling any necessary
  splitting or merging of existing chunks.
  """
  def split_or_merge_chunks(collection_id, start_line, end_line) do
    Logger.info(
      "Starting split_or_merge_chunks with start_line: #{inspect(start_line)}, end_line: #{inspect(end_line)}"
    )

    Repo.transaction(fn ->
      case find_affected_chunks(collection_id, start_line, end_line) do
        {:ok, [first_chunk | other_chunks]} ->
          Logger.info("calling reorganize_multiple_chunks")

          # Multiple chunks - use first as working chunk
          reorganize_multiple_chunks(first_chunk, other_chunks, start_line, end_line)

        {:error, _} = error ->
          Repo.rollback(error)
      end
    end)
  end

  defp create_chunk(collection_id, start_line, end_line, note) do
    %Chunk{}
    |> Chunk.changeset(%{
      "collection_id" => collection_id,
      "start_line" => start_line,
      "end_line" => end_line,
      "note" => note || ""
    })
    |> Repo.insert()
    |> case do
      {:ok, chunk} = result ->
        Logger.debug("Created chunk: #{inspect(chunk)}")
        result

      {:error, changeset} ->
        Logger.error("Failed to create chunk: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp find_affected_chunks(collection_id, start_line, end_line) do
    chunks =
      Repo.all(
        from c in Chunk,
          # and not is_nil(c.id)
          # and c.id != ^temp_chunk.id
          where:
            c.collection_id == ^collection_id and
              not is_nil(c.start_line) and
              not is_nil(c.end_line),
          order_by: c.start_line
      )

    affected =
      chunks
      |> Enum.filter(&chunk_overlaps?(&1, start_line, end_line))
      |> tap(fn chunks ->
        Logger.debug("Found affected chunks: #{inspect(chunks)}")
      end)

    {:ok, affected}
  end

  defp chunk_overlaps?(chunk, start_line, end_line) do
    with true <- is_number(start_line),
         true <- is_number(end_line),
         true <- is_number(chunk.start_line),
         true <- is_number(chunk.end_line) do
      (chunk.start_line >= start_line and chunk.start_line <= end_line) or
        (chunk.end_line >= start_line and chunk.end_line <= end_line) or
        (chunk.start_line <= start_line and chunk.end_line >= end_line)
    else
      _ -> false
    end
  end

  defp reorganize_multiple_chunks(first_chunk, other_chunks, new_start, new_end) do
    # First split off a new chunk for any lines before the new chunk starts
    # Move any note from the first selected chunk here, too.
    {:ok, working_chunk} =
      if first_chunk.start_line < new_start do
        {:ok, before_chunk} =
          create_chunk(
            first_chunk.collection_id,
            first_chunk.start_line,
            new_start - 1,
            first_chunk.note
          )

        {count, _} =
          from(l in Line,
            where:
              l.chunk_id == ^first_chunk.id and
                l.line_number >= ^first_chunk.start_line and
                l.line_number < ^new_start
          )
          |> Repo.update_all(set: [chunk_id: before_chunk.id])

        Logger.info("Moved #{count} lines to before chunk #{before_chunk.id}")

        with {:ok, working_chunk} <- update_chunk_note(first_chunk, ""), do: {:ok, working_chunk}
      else
        {:ok, first_chunk}
      end

    # Then move any lines that will be in the "after" section
    # second arg is a default for if other_chunks is empty; i.e. if we're only dealing with a single chunk.
    last_chunk = List.last(other_chunks, first_chunk)

    # {last_chunk, _} = List.pop_at(other_chunks, -1) # centre is the affected chunks minus the first and last
    Logger.info(
      "last line of last selected chunk: #{last_chunk.end_line}; last line of selection: #{new_end}"
    )

    if last_chunk.end_line > new_end do
      Logger.info("create after chunk for lines in last selected chunk after new_end")
      # No note on new last chunk
      {:ok, after_chunk} =
        create_chunk(last_chunk.collection_id, new_end + 1, last_chunk.end_line, "")

      {count, _} =
        from(l in Line,
          where:
            l.chunk_id == ^last_chunk.id and
              l.line_number > ^new_end and
              l.line_number <= ^last_chunk.end_line
        )
        |> Repo.update_all(set: [chunk_id: after_chunk.id])

      Logger.info("Moved #{count} lines to after chunk #{after_chunk.id}")
    end

    # If we're in this function, we're merging at least two cells.
    ## If there's a "before" chunk, we've given it the note, if any,
    ## from the working chunk and removed that note from the working
    ## chunk.
    ## Now just go through

    joined_notes =
      Enum.map([working_chunk | other_chunks], & &1.note)
      |> Enum.join("\n\n")

    {:ok, working_chunk} = update_chunk_note(working_chunk, joined_notes)

    # Logger.info("centre chunk list has length #{length(centre)}")
    # if centre != [] do
    # end

    # Move all affected lines not in before or after chunks to working chunk before deleting their original chunks
    Enum.each(other_chunks, fn chunk ->
      {count, _} =
        from(l in Line,
          where:
            l.chunk_id == ^chunk.id and
              l.line_number >= ^new_start and
              l.line_number <= ^new_end
        )
        |> Repo.update_all(set: [chunk_id: working_chunk.id])

      Logger.debug("Moved #{count} lines from chunk #{chunk.id} to working chunk")

      # Now safe to delete the chunk
      Repo.delete!(chunk)
      Logger.debug("Deleted chunk #{chunk.id}")
    end)

    # Finally update working chunk boundaries
    {:ok, updated_chunk} =
      working_chunk
      |> Chunk.changeset(%{"start_line" => new_start, "end_line" => new_end})
      |> Repo.update()

    # Verify no lines were orphaned
    orphaned_count =
      Repo.one(
        from l in Line,
          where:
            is_nil(l.chunk_id) and
              l.collection_id == ^working_chunk.collection_id and
              l.line_number >= ^new_start and
              l.line_number <= ^new_end,
          select: count()
      )

    if orphaned_count > 0 do
      Logger.error("Found #{orphaned_count} orphaned lines after reorganizing multiple chunks")
      raise "Lines became orphaned during chunk reorganization"
    end

    {:ok, updated_chunk}
  end

  def update_chunk(chunk, start_line, end_line, note) do
    Repo.transaction(fn ->
      # First update the chunk's range
      {:ok, updated_chunk} =
        chunk
        |> Chunk.changeset(%{
          "note" => note,
          "start_line" => start_line,
          "end_line" => end_line
        })
        |> Repo.update()

      # Update line associations within transaction
      {_, _} =
        from(l in Line,
          where:
            l.collection_id == ^chunk.collection_id and
              l.line_number >= ^start_line and
              l.line_number <= ^end_line
        )
        |> Repo.update_all(set: [chunk_id: updated_chunk.id])

      {:ok, updated_chunk}
    end)
  end

  @doc """
  Validates that we can safely delete a line.
  Returns :ok if safe to delete, {:error, reason} if not.
  """
  def validate_line_deletion(collection_id) do
    case count_lines(collection_id) do
      n when n > 1 -> :ok
      _ -> {:error, "Cannot delete the last line in a collection"}
    end
  end

  @doc """
  Gets the total number of lines in a collection.
  """
  def count_lines(collection_id) do
    Repo.one(
      from l in Line,
        where: l.collection_id == ^collection_id,
        select: count(l.id)
    )
  end

  # Private helper functions

  # defp create_initial_chunk(collection_id, line) do
  #   create_chunk(collection_id, line.line_number, line.line_number, "")
  # end

  @doc """
  Returns the list of collections.
  """
  def list_collections do
    Repo.all(Collection)
  end

  @doc """
  Gets a single collection.
  Raises if the Collection does not exist.
  """
  def get_collection!(id), do: Repo.get!(Collection, id)

  @doc """
  Creates a collection.
  """
  def create_collection(attrs \\ %{}) do
    %Collection{}
    |> Collection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a collection.
  """
  def update_collection(%Collection{} = collection, attrs) do
    collection
    |> Collection.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a collection.
  """
  def delete_collection(%Collection{} = collection) do
    Repo.delete(collection)
  end

  defp get_max_line_number(collection_id) do
    from(l in Line,
      where: l.collection_id == ^collection_id,
      select: max(l.line_number)
    )
    |> Repo.one() || -1
  end

  # defp shift_lines_up(collection_id, from_line_number) do
  #   from(l in Line,
  #     where: l.collection_id == ^collection_id and l.line_number >= ^from_line_number
  #   )
  #   |> Repo.update_all(inc: [line_number: 1])

  #   # Also update any affected chunks
  #   from(c in Chunk,
  #     where: c.collection_id == ^collection_id and c.start_line >= ^from_line_number
  #   )
  #   |> Repo.update_all(inc: [start_line: 1])

  #   from(c in Chunk,
  #     where: c.collection_id == ^collection_id and c.end_line >= ^from_line_number
  #   )
  #   |> Repo.update_all(inc: [end_line: 1])
  # end
end

defmodule Annotator.Lines do
  @moduledoc """
  The Lines context with simplified chunk handling.
  """

  import Ecto.Query
  alias Annotator.Repo
  alias Annotator.Lines.{Line, Collection, Chunk}
  require Logger

  @doc """
  Gets a collection with its lines and chunks preloaded.
  Lines will be ordered by line number.
  """
  def get_collection_with_lines(id) do
    Collection
    |> Repo.get(id)
    |> case do
      nil -> nil
      collection ->
        collection
        |> Repo.preload([
          lines: {
            from(l in Line,
              order_by: l.line_number,
              preload: [:chunk]
            ),
            :chunk
          }
        ])
        |> ensure_chunks_loaded()
    end
  end

  defp ensure_chunks_loaded(%Collection{} = collection) do
    # Ensure all lines have an associated chunk
    lines_with_chunks = Enum.map(collection.lines, fn line ->
      case line.chunk do
        %Ecto.Association.NotLoaded{} ->
          # Create a new chunk for this line if none exists
          {:ok, chunk} = create_initial_chunk(collection.id, line)
          %{line | chunk: chunk}
        _ ->
          line
      end
    end)

    %{collection | lines: lines_with_chunks}
  end

  @doc """
  Updates a line's content. If content contains newlines, splits into multiple lines
  and handles renumbering. Returns {:ok, collection} on success or {:error, reason} on failure.
  """
  def update_line!(collection_id, line_number, :content, value) do
    if String.contains?(value, "\n") do
      handle_content_split!(collection_id, line_number, value)
    else
      # Get existing line to preserve chunk association
      existing_line = Repo.one(
        from l in Line,
        where: l.collection_id == ^collection_id and l.line_number == ^line_number,
        preload: [:chunk]
      )

      attrs = %{
        line_number: line_number,
        content: value,
        collection_id: collection_id,
        chunk_id: existing_line.chunk_id
      }

      case upsert_line!(collection_id, attrs) do
        {:ok, line} ->
          # If this is a new line, ensure it has a chunk
          unless line.chunk_id do
            create_initial_chunk(collection_id, line)
          end
          {:ok, get_collection_with_lines(collection_id)}
        error -> error
      end
    end
  end

  @doc """
  Ensures the given line range is a single chunk, handling any necessary
  splitting or merging of existing chunks.
  """
  def ensure_chunk(collection_id, start_line, end_line) do
    Logger.info("Starting ensure_chunk with start_line: #{start_line}, end_line: #{end_line}")

    Repo.transaction(fn ->
      # Create a temporary chunk
      {:ok, temp_chunk} = %Chunk{}
      |> Chunk.changeset(%{
        "collection_id" => collection_id,
        "start_line" => 999999999,
        "end_line" => 999999999,
        "note" => "",
        "temporary" => true
      })
      |> Repo.insert()

      Logger.info("Created temp chunk: #{inspect(temp_chunk)}")

      # Find affected chunks
      affected_chunks = Repo.all(
        from c in Chunk,
        where: c.collection_id == ^collection_id
          and not is_nil(c.id)
          and c.id != ^temp_chunk.id
          and ((c.start_line >= ^start_line and c.start_line <= ^end_line) or
               (c.end_line >= ^start_line and c.end_line <= ^end_line) or
               (c.start_line <= ^start_line and c.end_line >= ^end_line)),
        order_by: c.start_line
      )

      Logger.info("Found affected chunks: #{inspect(affected_chunks)}")

      # Move all affected lines to temporary chunk first
      Enum.each(affected_chunks, fn chunk ->
        # Move lines to temp chunk
        {count, _} = from(l in Line,
          where: l.chunk_id == ^chunk.id
        )
        |> Repo.update_all(set: [chunk_id: temp_chunk.id])

        Logger.info("Moved #{count} lines from chunk #{chunk.id} to temp chunk")

        # Now it's safe to delete the chunk
        Repo.delete!(chunk)
        Logger.info("Deleted chunk #{chunk.id}")
      end)

      # Create new chunks for before/after sections if needed
      affected_chunks
      |> Enum.each(fn chunk ->
        if chunk.start_line < start_line do
          {:ok, before_chunk} = create_chunk(collection_id, chunk.start_line, start_line - 1, chunk.note)
          Logger.info("Created before chunk: #{inspect(before_chunk)}")
        end

        if chunk.end_line > end_line do
          {:ok, after_chunk} = create_chunk(collection_id, end_line + 1, chunk.end_line, chunk.note)
          Logger.info("Created after chunk: #{inspect(after_chunk)}")
        end
      end)

      # Create new target chunk
      {:ok, new_chunk} = create_chunk(collection_id, start_line, end_line, "")
      Logger.info("Created new target chunk: #{inspect(new_chunk)}")

      # Make sure all lines in range are assigned to new chunk
      {count, _} = from(l in Line,
        where: l.collection_id == ^collection_id
          and l.line_number >= ^start_line
          and l.line_number <= ^end_line
      )
      |> Repo.update_all(set: [chunk_id: new_chunk.id])

      Logger.info("Assigned #{count} lines to new chunk")

      # Delete temporary chunk
      Repo.delete!(temp_chunk)
      Logger.info("Deleted temporary chunk")

      {:ok, new_chunk}
    end)
  end

  defp create_chunk(collection_id, start_line, end_line, note) do
    chunk = %Chunk{}
    |> Chunk.changeset(%{
      "collection_id" => collection_id,
      "start_line" => start_line,
      "end_line" => end_line,
      "note" => note
    })
    |> Repo.insert!()

    # Move lines to this chunk
    {_, _} = from(l in Line,
      where: l.collection_id == ^collection_id
        and l.line_number >= ^start_line
        and l.line_number <= ^end_line
    )
    |> Repo.update_all(set: [chunk_id: chunk.id])

    {:ok, chunk}
  end

  # @doc """
  # Creates a new chunk or updates existing one based on line range.
  # """
  # def update_or_create_chunk(collection_id, start_line, end_line, note) do
  #   # Wrap everything in a transaction to ensure data consistency
  #   Repo.transaction(fn ->
  #     # Find any existing chunks that overlap with this range
  #     existing_chunks = Repo.all(
  #       from c in Chunk,
  #       where: c.collection_id == ^collection_id
  #         and c.start_line <= ^end_line
  #         and c.end_line >= ^start_line,
  #       order_by: c.start_line
  #     )

  #     case existing_chunks do
  #       [] ->
  #         # No overlapping chunks - create a new one
  #         case create_chunk(collection_id, start_line, end_line, note) do
  #           {:ok, chunk} -> {:ok, chunk}
  #           {:error, changeset} -> Repo.rollback(changeset)
  #         end

  #       [single_chunk] when single_chunk.start_line == start_line
  #                     and single_chunk.end_line == end_line ->
  #         # Exact match - just update the note if needed
  #         case update_chunk(single_chunk, start_line, end_line, note) do
  #           {:ok, chunk} -> {:ok, chunk}
  #           {:error, changeset} -> Repo.rollback(changeset)
  #         end

  #       chunks ->
  #         # Create the new chunk first so we have its ID
  #         case create_chunk(collection_id, start_line, end_line, note) do
  #           {:ok, new_chunk} ->
  #             # Update all affected lines to point to the new chunk
  #             {_count, _} = from(l in Line,
  #               where: l.collection_id == ^collection_id
  #                 and l.line_number >= ^start_line
  #                 and l.line_number <= ^end_line
  #             )
  #             |> Repo.update_all(set: [chunk_id: new_chunk.id])

  #             # Now that lines are reassigned, safely delete old chunks
  #             Enum.each(chunks, fn chunk ->
  #               # Clear any remaining line associations
  #               {_, _} = from(l in Line,
  #                 where: l.chunk_id == ^chunk.id
  #               )
  #               |> Repo.update_all(set: [chunk_id: new_chunk.id])

  #               # Now safe to delete the chunk
  #               Repo.delete!(chunk)
  #             end)

  #             {:ok, new_chunk}

  #           {:error, changeset} ->
  #             Repo.rollback(changeset)
  #         end
  #     end
  #   end)
  # end

  def update_chunk(chunk, start_line, end_line, note) do
    Repo.transaction(fn ->
      # First update the chunk's range
      {:ok, updated_chunk} = chunk
      |> Chunk.changeset(%{
        "note" => note,
        "start_line" => start_line,
        "end_line" => end_line
      })
      |> Repo.update()

      # Update line associations within transaction
      {_, _} = from(l in Line,
        where: l.collection_id == ^chunk.collection_id
          and l.line_number >= ^start_line
          and l.line_number <= ^end_line
      )
      |> Repo.update_all(set: [chunk_id: updated_chunk.id])

      {:ok, updated_chunk}
    end)
  end

  @doc """
  Merges two adjacent chunks.
  """
  def merge_chunks(chunk1_id, chunk2_id) do
    Repo.transaction(fn ->
      chunks = Repo.all(
        from c in Chunk,
        where: c.id in [^chunk1_id, ^chunk2_id]
      )

      case chunks do
        [chunk1, chunk2] when length(chunks) == 2 ->
          # Determine the new range
          start_line = min(chunk1.start_line, chunk2.start_line)
          end_line = max(chunk1.end_line, chunk2.end_line)

          # Create new chunk with combined range
          {:ok, merged} = create_chunk(
            chunk1.collection_id,
            start_line,
            end_line,
            chunk1.note
          )

          # Delete old chunks
          Repo.delete(chunk1)
          Repo.delete(chunk2)

          merged

        _ -> {:error, :chunks_not_found}
      end
    end)
  end

  def merge_chunks_range(collection_id, start_line, end_line) do
    # Find all chunks in range
    chunks = Repo.all(
      from c in Chunk,
      where: c.collection_id == ^collection_id
        and c.start_line >= ^start_line
        and c.end_line <= ^end_line,
      order_by: c.start_line
    )

    case chunks do
      [] -> {:error, :no_chunks_found}
      [single_chunk] -> {:ok, single_chunk}
      [first | rest] ->
        # Merge all chunks into first one
        Enum.reduce_while(rest, {:ok, first}, fn chunk, {:ok, acc} ->
          case merge_chunks(acc.id, chunk.id) do
            {:ok, merged} -> {:cont, {:ok, merged}}
            error -> {:halt, error}
          end
        end)
    end
  end

  def split_chunk_multiple(chunk, split_points) do
    Repo.transaction(fn ->
      Enum.reduce_while(split_points, {:ok, chunk}, fn split_point, {:ok, current_chunk} ->
        case split_chunk(current_chunk.id, split_point) do
          {:ok, {chunk1, chunk2}} -> {:cont, {:ok, chunk2}}
          error -> {:halt, error}
        end
      end)
    end)
  end

  @doc """
  Splits a chunk at the given line number, creating two new chunks.
  """
  def split_chunk(chunk_id, split_at_line) do
    Repo.transaction(fn ->
      chunk = Repo.get!(Chunk, chunk_id)

      # Only split if the line is within the chunk
      if split_at_line > chunk.start_line and split_at_line < chunk.end_line do
        # Create two new chunks
        {:ok, first} = create_chunk(
          chunk.collection_id,
          chunk.start_line,
          split_at_line - 1,
          chunk.note
        )

        {:ok, second} = create_chunk(
          chunk.collection_id,
          split_at_line,
          chunk.end_line,
          chunk.note
        )

        # Delete original chunk
        Repo.delete(chunk)

        {first, second}
      else
        {:error, :invalid_split_point}
      end
    end)
  end

  @doc """
  Deletes a line and updates related chunks and line numbers.
  """
  def delete_line(collection_id, line_id) do
    Repo.transaction(fn ->
      line = Repo.get_by!(Line, id: line_id, collection_id: collection_id)
      chunk = Repo.get!(Chunk, line.chunk_id)

      # Delete the line
      Repo.delete(line)

      # Update line numbers for subsequent lines
      from(l in Line,
        where: l.collection_id == ^collection_id and
               l.line_number > ^line.line_number
      )
      |> Repo.update_all(inc: [line_number: -1])

     # Update chunks that start after the deleted line
      from(c in Chunk,
      where: c.collection_id == ^collection_id and c.start_line > ^line.line_number
      )
      |> Repo.update_all(inc: [start_line: -1])

      # Update chunks that end after the deleted line
      from(c in Chunk,
      where: c.collection_id == ^collection_id and c.end_line > ^line.line_number
      )
      |> Repo.update_all(inc: [end_line: -1])
      # If this was the only line in the chunk, delete the chunk
      if chunk.start_line == chunk.end_line do
        Repo.delete(chunk)
      else
        # Otherwise update the chunk's range
        chunk_updates = if line.line_number == chunk.end_line do
          [end_line: chunk.end_line - 1]
        else
          [start_line: chunk.start_line - 1]
        end

        from(c in Chunk, where: c.id == ^chunk.id)
        |> Repo.update_all(set: chunk_updates)
      end

      line
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
    Repo.one(from l in Line,
      where: l.collection_id == ^collection_id,
      select: count(l.id)
    )
  end

  # Private helper functions



  defp handle_content_split!(collection_id, line_number, content) do
    content_lines = String.split(content, "\n")

    Repo.transaction(fn ->
      # Get the original line and its chunk
      original_line = Repo.get_by!(Line,
        collection_id: collection_id,
        line_number: line_number
      )
      chunk = Repo.get!(Chunk, original_line.chunk_id)

      # Delete the original line
      Repo.delete(original_line)

      # Shift subsequent lines
      offset = length(content_lines) - 1
      from(l in Line,
        where: l.collection_id == ^collection_id and l.line_number > ^line_number
      )
      |> Repo.update_all(inc: [line_number: offset])

      # Insert new lines
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      new_lines = content_lines
      |> Enum.with_index(line_number)
      |> Enum.map(fn {content, idx} ->
        %{
          collection_id: collection_id,
          line_number: idx,
          content: content,
          chunk_id: chunk.id,
          inserted_at: now,
          updated_at: now
        }
      end)

      {_, _inserted_lines} = Repo.insert_all(Line, new_lines, returning: true)

      # Update chunk's end_line if needed
      if chunk.end_line >= line_number do
        from(c in Chunk,
          where: c.collection_id == ^collection_id and c.end_line >= ^line_number
        )
        |> Repo.update_all(inc: [end_line: offset])
      end

      {:ok, get_collection_with_lines(collection_id)}
    end)
  end

  defp create_initial_chunk(collection_id, line) do
    create_chunk(collection_id, line.line_number, line.line_number, "")
  end

  def get_existing_chunks(collection_id, chunk_start, chunk_end) do
    Repo.all(
    from c in Chunk,
    where: c.collection_id == ^collection_id
      and ((c.start_line >= ^chunk_start and c.start_line <= ^chunk_end) or
           (c.end_line >= ^chunk_start and c.end_line <= ^chunk_end) or
           (c.start_line <= ^chunk_start and c.end_line >= ^chunk_end)),
    order_by: c.start_line
    )
  end

  @doc """
  Adds a new line to a collection.
  If line_number is not provided, appends to the end.
  Returns {:ok, line} or {:error, changeset}
  """
  def add_line(collection_id, attrs) do
    # Start transaction since we might need to update multiple records
    Repo.transaction(fn ->
      # Get the current max line number if none provided
      line_number = attrs[:line_number] || get_max_line_number(collection_id) + 1

      # Shift any existing lines to make room if needed
      if line_exists?(collection_id, line_number) do
        shift_lines_up(collection_id, line_number)
      end

      # Create the new line
      attrs = Map.merge(attrs, %{
        collection_id: collection_id,
        line_number: line_number
      })

      case %Line{}
      |> Line.changeset(attrs)
      |> Repo.insert() do
        {:ok, line} ->
          # Create an initial chunk for this line if it's not meant to be part of an existing chunk
          unless attrs[:chunk_id] do
            {:ok, chunk} = create_chunk(collection_id,
              line_number,
              line_number,
              ""
            )

            # Update the line with the new chunk_id
            line
            |> Line.changeset(%{chunk_id: chunk.id})
            |> Repo.update!()
          end

          line

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end


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

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking collection changes.
  """
  def change_collection(%Collection{} = collection, attrs \\ %{}) do
    Collection.changeset(collection, attrs)
  end


  defp upsert_line!(collection_id, attrs) do
    %Line{collection_id: collection_id}
    |> Line.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:content, :updated_at, :chunk_id]},
      conflict_target: [:collection_id, :line_number],
      returning: true
    )
  end

  defp get_max_line_number(collection_id) do
    from(l in Line,
      where: l.collection_id == ^collection_id,
      select: max(l.line_number)
    )
    |> Repo.one() || -1
  end

  defp line_exists?(collection_id, line_number) do
    from(l in Line,
      where: l.collection_id == ^collection_id and l.line_number == ^line_number
    )
    |> Repo.exists?()
  end

  defp shift_lines_up(collection_id, from_line_number) do
    from(l in Line,
      where: l.collection_id == ^collection_id and l.line_number >= ^from_line_number
    )
    |> Repo.update_all(inc: [line_number: 1])

    # Also update any affected chunks
    from(c in Chunk,
      where: c.collection_id == ^collection_id and c.start_line >= ^from_line_number
    )
    |> Repo.update_all(inc: [start_line: 1])

    from(c in Chunk,
      where: c.collection_id == ^collection_id and c.end_line >= ^from_line_number
    )
    |> Repo.update_all(inc: [end_line: 1])
  end
end

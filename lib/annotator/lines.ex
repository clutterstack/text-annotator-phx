
defmodule Annotator.Lines do
 @moduledoc """
  The Lines context.
  """

  import Ecto.Query, warn: false
  alias Annotator.Repo
  alias Annotator.Lines.{Line, Collection, Chunk, ChunkLine}
  require Logger

  @max_lines_per_transaction 500

  # Claude suggested some of these.
  # Untested. Upsert is (was) mine.

  # Get a collection with its lines
  def get_collection_with_lines(id) do
    Collection
    |> Repo.get(id)
    |> Repo.preload([lines: Line.ordered()])
  end

  # Update a single line -- I think I'm planning upserts only though so commenting out
  # def update_line(line, attrs) do
  #   line
  #   |> Line.changeset(attrs)
  #   |> Repo.update()
  # end

  # Add a new line to a collection
  def add_line(collection_id, attrs) do
    Repo.transaction fn ->
      {:ok, line} = %Line{collection_id: collection_id}
        |> Line.changeset(attrs)
        |> Repo.insert()

      {:ok, chunk} = create_chunk(collection_id, [line.id], "")

      line
    end
  end

  # Bulk insert lines -- superseded?
  # def create_lines(collection_id, lines_attrs) do
  #   lines_attrs
  #   |> Enum.map(fn attrs ->
  #     %{collection_id: collection_id} |> Map.merge(attrs)
  #   end)
  #   |> Enum.map(&(Line.changeset(%Line{}, &1)))
  #   |> Enum.reduce(Ecto.Multi.new(), fn changeset, multi ->
  #     Ecto.Multi.insert(multi, {:line, changeset.changes.line_number}, changeset)
  #   end)
  #   |> Repo.transaction()
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

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking collection changes.
  """
  def change_collection(%Collection{} = collection, attrs \\ %{}) do
    Collection.changeset(collection, attrs)
  end

@doc """
  Updates a line's content.
  If content contains newlines, splits into multiple lines and handles renumbering.
  Returns {:ok, _} on success or {:error, reason} on failure.
  """
  def update_line!(collection_id, line_number, :content, value) do
    if String.contains?(value, "\n") do
      handle_content_split!(collection_id, line_number, value)
    else
      # Get existing line to preserve other fields
      existing_line = case Repo.one(
        from l in Line,
        where: l.collection_id == ^collection_id and l.line_number == ^line_number,
        preload: [chunks: :chunk_lines]
      ) do
        nil -> %Line{content: ""}
        line -> line
      end

      # Create attrs map with just the content update
      attrs = %{
        line_number: line_number,
        content: value,
        collection_id: collection_id
      }

      case upsert_line!(collection_id, attrs) do
        {:ok, line} ->
          # If this is the first line, create initial chunk
          unless line.id in (existing_line.chunks |> Enum.flat_map(& &1.chunk_lines) |> Enum.map(& &1.line_id)) do
            create_initial_chunk(collection_id, [line])
          end
          {:ok, get_collection_with_lines(collection_id)}
        error -> error
      end
    end
  end

  # Split content into multiple lines with efficient bulk operations.
  # All operations are wrapped in a transaction for consistency.
defp handle_content_split!(collection_id, start_line_number, content) do
    content_lines = String.split(content, "\n")
    # new_lines_count = length(content_lines)

    Logger.info("\n=== Starting Content Split ===")
    Logger.info("Start line: #{start_line_number}")
    Logger.info("Content lines: #{inspect(content_lines)}")

    Repo.transaction(fn ->
      # Get the original line and its chunks
      {original_line, affected_chunks} = get_line_and_chunks(collection_id, start_line_number)

      Logger.info("\nOriginal line to edit:")
      Logger.info("ID: #{original_line && original_line.id}")
      Logger.info("Number: #{original_line && original_line.line_number}")
      Logger.info("Content: #{original_line && original_line.content}")

      # Get all lines that will be affected (the line we're editing and any subsequent lines)
      lines_to_update = Repo.all(
        from l in Line,
        where: l.collection_id == ^collection_id and l.line_number >= ^start_line_number,
        order_by: l.line_number
      )

      # Delete all affected lines
      line_ids = Enum.map(lines_to_update, & &1.id)
      Repo.delete_all(from l in Line, where: l.id in ^line_ids)

      Logger.info("\nDeleted lines with IDs: #{inspect(line_ids)}")

      # Insert all lines (original content plus new content)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Prepare all new lines
      new_lines_params = content_lines
      |> Enum.with_index(start_line_number)
      |> Enum.map(fn {content, idx} ->
        %{
          collection_id: collection_id,
          line_number: idx,
          content: content,
          inserted_at: now,
          updated_at: now
        }
      end)

      {inserted_count, new_lines} = Repo.insert_all(Line, new_lines_params, returning: true)

      Logger.info("\nInserted #{inserted_count} new lines:")
      for line <- new_lines do
        Logger.info("Line #{line.line_number}: '#{line.content}' (ID: #{line.id})")
      end

      # Handle chunk associations
      if Enum.empty?(affected_chunks) do
        # If no existing chunks, create a new one for all lines
        Logger.info("\nCreating new chunk for all lines")
        create_initial_chunk(collection_id, new_lines)
      else
        # Add all new lines to existing chunks
        chunk_lines = for chunk <- affected_chunks,
                         line <- new_lines do
          %{
            chunk_id: chunk.id,
            line_id: line.id,
            inserted_at: now,
            updated_at: now
          }
        end

        {chunk_assoc_count, _} = Repo.insert_all(ChunkLine, chunk_lines)
        Logger.info("\nAdded #{chunk_assoc_count} chunk associations")
      end

      {:ok, get_collection_with_lines(collection_id)}
    end)
  end

  defp create_initial_chunk(collection_id, lines) do
    Logger.info("Creating initial chunk for lines: #{inspect(Enum.map(lines, & &1.line_number))}")

    %Chunk{}
    |> Chunk.changeset(%{
      collection_id: collection_id,
      note: "",
      line_ids: Enum.map(lines, & &1.id)
    })
    |> Repo.insert()
  end


  # Shift line numbers safely
  # defp shift_existing_lines(collection_id, start_line_number, offset) do
  #   # Get all lines that need to be shifted
  #   lines_to_shift = Repo.all(
  #     from l in Line,
  #     where: l.collection_id == ^collection_id and l.line_number >= ^start_line_number,
  #     order_by: [desc: l.line_number]  # Important: update highest numbers first
  #   )

  #   # Update each line's number individually to avoid conflicts
  #   for line <- lines_to_shift do
  #     Repo.update_all(
  #       from(l in Line,
  #         where: l.id == ^line.id
  #       ),
  #       set: [
  #         line_number: line.line_number + offset,
  #         updated_at: DateTime.utc_now()
  #       ]
  #     )
  #   end
  # end

# Update chunk associations for the split lines
# defp update_chunk_associations(new_lines, nil, _), do: :ok
# defp update_chunk_associations(new_lines, _original_line, []), do: :ok
# defp update_chunk_associations(new_lines, original_line, affected_chunks) do
#   now = DateTime.utc_now() |> DateTime.truncate(:second)

#   # Create new associations
#   chunk_lines = for chunk <- affected_chunks,
#                    line <- new_lines,
#                    do: %{
#                      chunk_id: chunk.id,
#                      line_id: line.id,
#                      inserted_at: now,
#                      updated_at: now
#                    }

#   case Repo.insert_all(ChunkLine, chunk_lines) do
#     {_, _} -> :ok
#     error -> {:error, "Failed to update chunk associations: #{inspect(error)}"}
#   end
# end

  # Remove any chunks that ended up empty after the split
  # defp cleanup_empty_chunks(collection_id) do
  #   {_, _} = Repo.delete_all(
  #     from c in Chunk,
  #     where: c.collection_id == ^collection_id,
  #     where: c.id not in subquery(
  #       from(cl in ChunkLine, select: cl.chunk_id)
  #     )
  #   )
  #   :ok
  # end

@doc """
  Gets a summary of chunks and their line coverage for a collection.
  Useful for debugging and verification.
  """
  def get_chunk_coverage(collection_id) do
    Repo.all(
      from c in Chunk,
      where: c.collection_id == ^collection_id,
      join: cl in assoc(c, :chunk_lines),
      join: l in assoc(cl, :line),
      group_by: c.id,
      select: %{
        chunk_id: c.id,
        note: c.note,
        line_count: count(cl.id),
        min_line: min(l.line_number),
        max_line: max(l.line_number)
      }
    )
  end

  defp upsert_line!(collection_id, attrs) do
    %Line{collection_id: collection_id}
    |> Line.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:content, :updated_at]},
      conflict_target: [:collection_id, :line_number],
      returning: true
    )
  end

   # Get the line being split and any chunks it belongs to
  defp get_line_and_chunks(collection_id, line_number) do
  line_with_chunks = Repo.one(
    from l in Line,
    where: l.collection_id == ^collection_id and l.line_number == ^line_number,
    left_join: cl in assoc(l, :chunk_lines),
    left_join: c in assoc(cl, :chunk),
    preload: [chunks: c]
  )

  {line_with_chunks, line_with_chunks && line_with_chunks.chunks || []}
  end

  # defp validate_split_operation!(collection_id, start_line_number, new_lines_count) do
  #   # Check for transaction size limit
  #   if new_lines_count > @max_lines_per_transaction do
  #     raise "Split would create #{new_lines_count} lines, exceeding limit of #{@max_lines_per_transaction}"
  #   end

  #   # Count how many lines would be affected by this operation
  #   affected_lines = Repo.one(
  #     from l in Line,
  #     where: l.collection_id == ^collection_id and
  #            l.line_number >= ^start_line_number,
  #     select: count(l.id)
  #   )

  #   # If total affected lines (existing + new - 1 for the original line) would exceed limit, reject
  #   if affected_lines + new_lines_count - 1 > @max_lines_per_transaction do
  #     raise "Operation would affect #{affected_lines + new_lines_count - 1} lines, exceeding limit of #{@max_lines_per_transaction}"
  #   end
  # end

  # Insert the new lines from the split content
  # defp insert_split_lines(collection_id, start_line_number, content_lines) do
  #   now = DateTime.utc_now() |> DateTime.truncate(:second)

  #   new_lines = content_lines
  #   |> Enum.with_index(start_line_number)
  #   |> Enum.map(fn {content, idx} ->
  #     %{
  #       collection_id: collection_id,
  #       line_number: idx,
  #       content: content,
  #       inserted_at: now,
  #       updated_at: now
  #     }
  #   end)

  #   # Use insert_all without on_conflict since we've already deleted the original line
  #   case Repo.insert_all(Line, new_lines, returning: true) do
  #     {count, lines} when count == length(content_lines) ->
  #       {:ok, lines}
  #     {count, _} ->
  #       {:error, "Expected to insert #{length(content_lines)} lines, but inserted #{count}"}
  #   end
  # end

  @doc """
  Deletes a line and renumbers subsequent lines in a single transaction.
  Uses a bulk update for better efficiency.
  """
  def delete_line!(collection_id, line_number) do
    Repo.transaction(fn ->
      # Delete the line
      {1, _} = Repo.delete_all(
        from l in Line,
        where: l.collection_id == ^collection_id and l.line_number == ^line_number
      )

      # Bulk update all subsequent line numbers
      {_, _} = Repo.update_all(
        from(l in Line,
          where: l.collection_id == ^collection_id and l.line_number > ^line_number
        ),
        inc: [line_number: -1]
      )
    end)
  end

    @doc """
  Deletes a line and updates related line numbers and chunk associations.

  Returns {:ok, deleted_line} on success or {:error, reason} on failure.
  """
  def delete_line(collection_id, line_id) do
    line = Repo.get_by!(Line, id: line_id, collection_id: collection_id)

    # Start a transaction since we need to maintain consistency
    # across multiple related updates
    Repo.transaction(fn ->
      # First delete any chunk_lines referencing this line
      {_deleted_count, _} = from(cl in ChunkLine,
        where: cl.line_id == ^line_id
      )
      |> Repo.delete_all()

      # Delete the line itself
      case Repo.delete(line) do
        {:ok, deleted_line} ->
          # Update line numbers for all subsequent lines
          from(l in Line,
            where: l.collection_id == ^collection_id and
                   l.line_number > ^line.line_number,
            update: [inc: [line_number: -1]]
          )
          |> Repo.update_all([])

          # Clean up any chunks that now have no lines
          {_deleted_chunks, _} = from(c in Chunk,
            where: c.collection_id == ^collection_id,
            where: c.id not in subquery(
              from(cl in ChunkLine, select: cl.chunk_id)
            )
          )
          |> Repo.delete_all()

          deleted_line

        {:error, changeset} ->
          Repo.rollback({:delete_failed, changeset})
      end
    end)
    |> case do
      {:ok, deleted_line} -> {:ok, deleted_line}
      {:error, {:delete_failed, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
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
  Updates chunk boundaries when lines are deleted.
  Removes deleted lines from chunks but preserves the chunks themselves.
  """
  def handle_lines_deleted(collection_id, deleted_line_ids) do
    Repo.transaction(fn ->
      # Delete chunk_lines entries for deleted lines
      {_, _} = Repo.delete_all(
        from cl in ChunkLine,
        join: c in assoc(cl, :chunk),
        where: c.collection_id == ^collection_id and
               cl.line_id in ^deleted_line_ids
      )

      # Optionally: Delete any chunks that now have no lines
      {_, _} = Repo.delete_all(
        from c in Chunk,
        left_join: cl in assoc(c, :chunk_lines),
        where: c.collection_id == ^collection_id and
               is_nil(cl.id),
        group_by: c.id
      )
    end)
  end

  def list_chunks(collection_id) do
    Repo.all(
      from c in Chunk,
      where: c.collection_id == ^collection_id,
      preload: [chunk_lines: :line]
    )
  end


  @doc """
  Creates or updates a chunk for the given lines.
  If any of the lines are already in a chunk, that chunk will be updated.
  """
  def update_or_create_chunk(collection_id, line_ids, note) do
    Repo.transaction(fn ->
      # Check if any of these lines are already in a chunk
      existing_chunk = Repo.one(
        from c in Chunk,
        join: cl in assoc(c, :chunk_lines),
        where: cl.line_id in ^line_ids,
        preload: [chunk_lines: :line]
      )

      case existing_chunk do
        nil -> create_chunk(collection_id, line_ids, note)
        chunk -> update_chunk(chunk, line_ids, note)
      end
    end)
  end

  @doc """
  Creates a new chunk with the given lines.
  """
  def create_chunk(collection_id, line_ids, note) do
    %Chunk{}
    |> Chunk.changeset(%{
      collection_id: collection_id,
      note: note,
      line_ids: line_ids
    })
    |> Repo.insert()
  end

  @doc """
  Updates an existing chunk, replacing its lines with the new set.
  """
  def update_chunk(chunk, line_ids, note) do
    # Ensure chunk is loaded with its associations
    chunk = Repo.preload(chunk, :chunk_lines)

    chunk
    |> Chunk.changeset(%{
      note: note,
      line_ids: line_ids
    })
    |> Repo.update()
  end

  @doc """
  Expands a chunk to include additional consecutive lines.
  Returns error if the lines would create a gap or overlap with another chunk.
  """
  def expand_chunk(chunk_id, new_line_ids) do
    Repo.transaction(fn ->
      chunk = Repo.get!(Chunk, chunk_id) |> Repo.preload(chunk_lines: :line)

      current_line_ids = Enum.map(chunk.chunk_lines, & &1.line_id)
      all_line_ids = Enum.sort(current_line_ids ++ new_line_ids)

      chunk
      |> Chunk.changeset(%{
        note: chunk.note,
        line_ids: all_line_ids
      })
      |> Repo.update()
    end)
  end

  @doc """
  Splits a chunk at the given line number, creating two new chunks.
  The original chunk is deleted.
  """
  def split_chunk(chunk_id, split_at_line_number) do
    Repo.transaction(fn ->
      # Get the chunk with its lines, ordered by line number
      chunk = Repo.one(
        from c in Chunk,
        where: c.id == ^chunk_id,
        join: cl in assoc(c, :chunk_lines),
        join: l in assoc(cl, :line),
        order_by: l.line_number,
        preload: [chunk_lines: {cl, line: l}]
      )

      # First delete all existing chunk_lines
      {_, _} = Repo.delete_all(
        from cl in ChunkLine,
        where: cl.chunk_id == ^chunk_id
      )

      # Split the lines into two groups
      {first_lines, second_lines} = Enum.split_with(
        chunk.chunk_lines, fn cl -> cl.line.line_number < split_at_line_number
        end)

      first_line_ids = Enum.map(first_lines, & &1.line_id)
      second_line_ids = Enum.map(second_lines, & &1.line_id)

      # Create two new chunks
      with {:ok, first_chunk} <- create_chunk(chunk.collection_id, first_line_ids, chunk.note),
           {:ok, second_chunk} <- create_chunk(chunk.collection_id, second_line_ids, chunk.note),
           {:ok, _} <- Repo.delete(chunk) do
        {first_chunk, second_chunk}
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Merges two chunks if they are adjacent.
  Returns error if chunks are not adjacent or belong to different collections.
  """
  def merge_chunks(chunk1_id, chunk2_id) do
    Repo.transaction(fn ->
      chunks = Repo.all(
        from c in Chunk,
        where: c.id in [^chunk1_id, ^chunk2_id],
        preload: [chunk_lines: :line]
      )

      case chunks do
        [chunk1, chunk2] when length(chunks) == 2 ->
          all_line_ids = (chunk1.chunk_lines ++ chunk2.chunk_lines)
          |> Enum.sort_by(& &1.line.line_number)
          |> Enum.map(& &1.line_id)

          with {:ok, merged} <- create_chunk(chunk1.collection_id, all_line_ids, chunk1.note),
               {:ok, _} <- Repo.delete(chunk1),
               {:ok, _} <- Repo.delete(chunk2) do
            merged
          end
        _ ->
          {:error, :chunks_not_found}
      end
    end)
  end
end

defmodule Annotator.Lines.Chunk do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Annotator.Repo
  alias Annotator.Lines.{Line, ChunkLine}

  schema "chunks" do
    field :note, :string
    belongs_to :collection, Annotator.Lines.Collection
    has_many :chunk_lines, ChunkLine, on_replace: :delete
    has_many :lines, through: [:chunk_lines, :line]
    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a new chunk or updates an existing one.
  Accepts the following parameters:
  - note: The text content of the note
  - collection_id: The ID of the collection this chunk belongs to
  - line_ids: List of line IDs that this chunk should contain
  """
  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:note, :collection_id])
    |> validate_required([:collection_id])
    |> validate_note_length()
    |> validate_line_ids(attrs)
    |> prepare_chunk_lines(attrs)
    |> validate_lines_exist()
    |> validate_lines_in_same_collection()
    |> validate_sequential_lines()
  end

  # Validates that line_ids is present and is a list
  defp validate_line_ids(changeset, attrs) do
    case attrs do
      %{line_ids: ids} when is_list(ids) and ids != [] ->
        changeset
      %{"line_ids" => ids} when is_list(ids) and ids != [] ->
        changeset
      _ ->
        add_error(changeset, :line_ids, "must be provided and contain at least one line")
    end
  end

  # Prepares chunk_lines associations based on line_ids
  defp prepare_chunk_lines(changeset, attrs) do
    case get_line_ids(attrs) do
      [] -> changeset
      line_ids ->
        chunk_lines = Enum.map(line_ids, fn line_id ->
          %{line_id: line_id}
        end)
        put_assoc(changeset, :chunk_lines, chunk_lines)
    end
  end

  # Helper to extract line_ids from attrs, handling both string and atom keys
  defp get_line_ids(attrs) do
    case attrs do
      %{line_ids: ids} -> ids
      %{"line_ids" => ids} -> ids
      _ -> []
    end
  end

  # Validates that all referenced lines exist in the database
  defp validate_lines_exist(changeset) do
    case get_line_ids(changeset.params) do
      [] -> changeset
      line_ids ->
        existing_count = Repo.one(from l in Line, where: l.id in ^line_ids, select: count())

        if existing_count == length(line_ids) do
          changeset
        else
          add_error(changeset, :line_ids, "contains non-existent lines")
        end
    end
  end

  # Validates that all lines belong to the same collection as the chunk
  defp validate_lines_in_same_collection(changeset) do
    with collection_id when not is_nil(collection_id) <- get_field(changeset, :collection_id),
         line_ids when line_ids != [] <- get_line_ids(changeset.params) do

      query = from l in Line,
        where: l.id in ^line_ids and l.collection_id != ^collection_id

      case Repo.exists?(query) do
        true -> add_error(changeset, :line_ids, "must all belong to the same collection")
        false -> changeset
      end
    else
      _ -> changeset
    end
  end

  # Validates that all lines in the chunk are sequential
  defp validate_sequential_lines(changeset) do
    with line_ids when line_ids != [] <- get_line_ids(changeset.params) do
      lines = Repo.all(from l in Line,
        where: l.id in ^line_ids,
        order_by: l.line_number,
        select: %{id: l.id, line_number: l.line_number}
      )

      line_numbers = Enum.map(lines, & &1.line_number)
      expected_range = Enum.to_list(List.first(line_numbers)..List.last(line_numbers))

      if line_numbers == expected_range do
        changeset
      else
        add_error(changeset, :line_ids, "must be sequential lines")
      end
    else
      _ -> changeset
    end
  end

  # Validates the length of the note field
  defp validate_note_length(changeset) do
    changeset
    |> validate_length(:note,
      min: 1,
      max: 10_000,
      message: "must be between 1 and 10,000 characters"
    )
  end

  @doc """
  Returns all chunks in a collection, sorted by the minimum line number in each chunk.
  """
  def ordered_by_line_number(query \\ __MODULE__) do
    from c in query,
      join: cl in assoc(c, :chunk_lines),
      join: l in assoc(cl, :line),
      group_by: c.id,
      order_by: min(l.line_number)
  end


end

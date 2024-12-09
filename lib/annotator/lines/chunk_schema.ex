defmodule Annotator.Lines.Chunk do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Annotator.Repo
  alias Annotator.Lines.Line

  schema "chunks" do
    field :note, :string, default: ""
    field :start_line, :integer
    field :end_line, :integer
    field :temporary, :boolean, default: false
    belongs_to :collection, Annotator.Lines.Collection
    has_many :lines, Annotator.Lines.Line, on_delete: :nilify_all
    timestamps(type: :utc_datetime)
  end

  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:note, :collection_id, :start_line, :end_line, :temporary])
    |> validate_required([:collection_id, :start_line, :end_line])
    |> foreign_key_constraint(:name)
    |> validate_number(:start_line, greater_than_or_equal_to: 0)
    |> validate_number(:end_line, greater_than_or_equal_to: 0)
    |> validate_end_line_after_start_line()
    |> maybe_validate_no_overlap()
    |> maybe_validate_lines_exist()
  end

  defp maybe_validate_no_overlap(changeset) do
    if get_field(changeset, :temporary) do
      changeset
    else
      validate_no_overlap(changeset)
    end
  end

  defp maybe_validate_lines_exist(changeset) do
    if get_field(changeset, :temporary) do
      changeset
    else
      validate_lines_exist(changeset)
    end
  end

  defp validate_end_line_after_start_line(changeset) do
    case {get_field(changeset, :start_line), get_field(changeset, :end_line)} do
      {start_line, end_line} when not is_nil(start_line) and not is_nil(end_line) ->
        if end_line >= start_line do
          changeset
        else
          add_error(changeset, :end_line, "must be greater than or equal to start_line")
        end
      _ -> changeset
    end
  end

  defp validate_no_overlap(changeset) do
    case {get_field(changeset, :collection_id),
          get_field(changeset, :start_line),
          get_field(changeset, :end_line),
          get_field(changeset, :id)} do
      {nil, _, _, _} -> changeset
      {_, nil, _, _} -> changeset
      {_, _, nil, _} -> changeset
      {collection_id, start_line, end_line, chunk_id} ->
        # Base query for overlapping chunks
        base_query = from c in __MODULE__,
          where: c.collection_id == ^collection_id and
            ((c.start_line <= ^end_line and c.end_line >= ^start_line) or
            (c.start_line >= ^start_line and c.start_line <= ^end_line) or
            (c.end_line >= ^start_line and c.end_line <= ^end_line))

        # Add ID condition only if we have an ID
        query = if chunk_id do
          from c in base_query, where: c.id != ^chunk_id
        else
          base_query
        end

        case Repo.exists?(query) do
          true -> add_error(changeset, :base, "chunk overlaps with existing chunk")
          false -> changeset
        end
    end
  end

  defp validate_lines_exist(changeset) do
    # Skip validation if this is a temporary chunk
    case {get_field(changeset, :temporary),
          get_field(changeset, :collection_id),
          get_field(changeset, :start_line),
          get_field(changeset, :end_line)} do
      {true, _, _, _} ->
        changeset
      {_, collection_id, start_line, end_line} when not is_nil(collection_id)
                                               and not is_nil(start_line)
                                               and not is_nil(end_line) ->
        # Check if all lines in the range exist
        expected_count = end_line - start_line + 1
        query = from l in Line,
          where: l.collection_id == ^collection_id and
                 l.line_number >= ^start_line and
                 l.line_number <= ^end_line,
          select: count()

        case Repo.one(query) do
          ^expected_count -> changeset
          actual_count ->
            add_error(changeset, :base,
              "not all lines in range exist (expected #{expected_count}, found #{actual_count})")
        end
      _ -> changeset
    end
  end

  def ordered_by_line_number(query \\ __MODULE__) do
    from c in query, order_by: c.start_line
  end
end

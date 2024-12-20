defmodule Annotator.Lines.Chunk do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

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

    # |> maybe_validate_no_overlap()
    # |> maybe_validate_lines_exist()
  end

  defp validate_end_line_after_start_line(changeset) do
    case {get_field(changeset, :start_line), get_field(changeset, :end_line)} do
      {start_line, end_line} when not is_nil(start_line) and not is_nil(end_line) ->
        if end_line >= start_line do
          changeset
        else
          add_error(changeset, :end_line, "must be greater than or equal to start_line")
        end

      _ ->
        changeset
    end
  end

  def ordered_by_line_number(query \\ __MODULE__) do
    from c in query, order_by: c.start_line
  end
end

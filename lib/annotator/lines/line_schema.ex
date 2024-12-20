defmodule Annotator.Lines.Line do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "lines" do
    field :line_number, :integer
    field :content, :string
    belongs_to :collection, Annotator.Lines.Collection
    belongs_to :chunk, Annotator.Lines.Chunk, on_replace: :nilify
    timestamps(type: :utc_datetime)
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [:line_number, :content, :collection_id, :chunk_id])
    |> validate_required([:line_number, :collection_id, :chunk_id])
    |> foreign_key_constraint(:collection_id)
    |> foreign_key_constraint(:chunk_id)

    # |> unique_constraint([:collection_id, :line_number]) # not sure what to do here but it's hard to renumber lines without violating this
  end

  def by_collection(query \\ __MODULE__, collection_id) do
    where(query, [l], l.collection_id == ^collection_id)
  end

  def ordered(query \\ __MODULE__) do
    order_by(query, [l], l.line_number)
  end
end

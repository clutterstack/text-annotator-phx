defmodule Annotator.Lines.Line do
  @doc "data for an annotator interface"
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "lines" do
    field :line_number, :integer
    field :content, :string
    field :note, :string

    belongs_to :collection, Annotator.Lines.Collection

    timestamps(type: :utc_datetime)
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [:line_number, :content, :note, :collection_id])
    |> validate_required([:line_number, :collection_id])
    |> foreign_key_constraint(:collection_id)
    |> unique_constraint([:collection_id, :line_number])
  end

  # Helper functions for common queries
  def by_collection(query \\ __MODULE__, collection_id) do
    where(query, [l], l.collection_id == ^collection_id)
  end

  def ordered(query \\ __MODULE__) do
    order_by(query, [l], l.line_number)
  end
end

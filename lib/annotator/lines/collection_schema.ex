defmodule Annotator.Lines.Collection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "collections" do
    field :name, :string
    has_many :lines, Annotator.Lines.Line
    timestamps(type: :utc_datetime)
  end

  def changeset(collection, attrs) do
    collection
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  # Helper function to get lines count (a helpful
  # example from Claude, assuming it works; I don't
  # need it yet)
  def lines_count(collection) do
    collection
    |> Ecto.assoc(:lines)
    |> Annotator.Repo.aggregate(:count)
  end
end


defmodule Annotator.Lines do
 @moduledoc """
  The Lines context.
  """

  import Ecto.Query, warn: false
  alias Annotator.Repo
  alias Annotator.Lines.{Line, Collection}


  # Claude suggested some of these.
  # Untested. Upsert is mine.

  # Get a collection with its lines
  def get_collection_with_lines(id) do
    Collection
    |> Repo.get(id)
    |> Repo.preload([lines: Line.ordered()])
  end

  # Update a single line
  def update_line(line, attrs) do
    line
    |> Line.changeset(attrs)
    |> Repo.update()
  end

  # Add a new line to a collection
  def add_line(collection_id, attrs) do
    %Line{collection_id: collection_id}
    |> Line.changeset(attrs)
    |> Repo.insert()
  end

  # Bulk insert lines
  def create_lines(collection_id, lines_attrs) do
    lines_attrs
    |> Enum.map(fn attrs ->
      %{collection_id: collection_id} |> Map.merge(attrs)
    end)
    |> Enum.map(&(Line.changeset(%Line{}, &1)))
    |> Enum.reduce(Ecto.Multi.new(), fn changeset, multi ->
      Ecto.Multi.insert(multi, {:line, changeset.changes.line_number}, changeset)
    end)
    |> Repo.transaction()
  end

  def upsert_line!(collection_id, attrs) do
    %Line{collection_id: collection_id}
    # IO.inspect(attrs, label: "trying to upsert! attrs:")
    |> Line.changeset(attrs)
    # |> IO.inspect()
    |> Repo.insert!(on_conflict: :replace_all)
  end

end

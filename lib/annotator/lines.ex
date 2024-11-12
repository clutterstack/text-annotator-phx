
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

  # Update a single line -- I think I'm planning upserts only though so commenting out
  # def update_line(line, attrs) do
  #   line
  #   |> Line.changeset(attrs)
  #   |> Repo.update()
  # end

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
    result = %Line{collection_id: collection_id}
    # IO.inspect(attrs, label: "trying to upsert! attrs:")
    |> Line.changeset(attrs)
    # |> IO.inspect()
    |> Repo.insert!(on_conflict: :replace_all)
    {:ok, result}
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

@doc """
  Updates a line's content or note.
  If content contains newlines, splits into multiple lines and handles renumbering.
  Returns {:ok, _} on success or {:error, reason} on failure.
  """
  def update_line!(collection_id, line_number, field, value) when field in [:content, :note] do
    if field == :content && String.contains?(value, "\n") do
      handle_content_split!(collection_id, line_number, value)
    else
      # Get existing line to preserve other fields
      existing_line = case Repo.one(
        from l in Line,
        where: l.collection_id == ^collection_id and l.line_number == ^line_number
      ) do
        nil -> %Line{content: "", note: ""}
        line -> %Line{line |
          content: line.content || "",
          note: line.note || ""
        }
      end

      # Create attrs map with all fields, using existing values except for the updated field
      attrs = %{
        line_number: line_number,
        content: if(field == :content, do: value, else: existing_line.content),
        note: if(field == :note, do: value, else: existing_line.note)
      }

      upsert_line!(collection_id, attrs)
    end
  end


  # Split content into multiple lines with efficient bulk operations.
  # All operations are wrapped in a transaction for consistency.
  defp handle_content_split!(collection_id, start_line_number, content) do
    content_lines = String.split(content, "\n")
    new_lines_count = length(content_lines)

    Repo.transaction(fn ->
      # First, shift existing lines down to make room for new lines
      {_, _} = Repo.update_all(
        from(l in Line,
        where: l.collection_id == ^collection_id and
              l.line_number > ^start_line_number
        ),
        inc: [line_number: new_lines_count - 1]  # -1 because one line is being replaced
      )

      # Ecto doesn't handle timestamps when we use Repo.insert_all
      # so we need to generate them
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Bulk insert new lines from the split content
      new_lines = content_lines
      |> Enum.with_index(start_line_number)
      |> Enum.map(fn {line_content, idx} ->
        %{
          collection_id: collection_id,
          line_number: idx,
          content: line_content,
          note: "",
          inserted_at: now,
          updated_at: now
        }
      end)

      {_, _} = Repo.insert_all(Line, new_lines,
        on_conflict: {:replace, [:content, :updated_at]},
        conflict_target: [:collection_id, :line_number]
      )

    end)
  end

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
end

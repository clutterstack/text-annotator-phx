defmodule AnnotatorWeb.ExportController do
  use AnnotatorWeb, :controller
  alias Annotator.Lines
  alias AnnotatorWeb.ExportComponents
  alias AnnotatorWeb.AnnotatorComponents
  require Logger
  # import vs. alias: https://elixirforum.com/t/alias-vs-import-performance/4195/4
  # Compile-time dependency, but seemingly no runtime disadvantage
  # If I just alias, I have to write `SharedHelpers.` in front of every shared function name
  import Annotator.SharedHelpers

  def html_grid(conn, %{"id" => id}) do
    case Lines.get_collection_with_assocs(id) do
      nil ->
        conn
        |> put_flash(:error, "Collection not found")
        |> redirect(to: ~p"/collections")

      collection ->
        chunk_groups = get_chunk_groups(collection.lines)
        # lang = collection.lang

        string_to_render =
          AnnotatorComponents.HtmlGrid.html_grid(%{chunk_groups: chunk_groups, lang: collection.lang, id: id })
          |> Phoenix.HTML.html_escape()
          |> Phoenix.HTML.safe_to_string()
          |> String.trim()

        text(conn, string_to_render)
    end
  end

  def html_divs(conn, %{"id" => id}) do
    case Lines.get_collection_with_assocs(id) do
      nil ->
        conn
        |> put_flash(:error, "Collection not found")
        |> redirect(to: ~p"/collections")

      collection ->
        chunk_groups = get_chunk_groups(collection.lines)
        # lang = collection.lang

        string_to_render =
          ExportComponents.html_divs(%{chunk_groups: chunk_groups, lang: collection.lang, id: id })
          |> Phoenix.HTML.html_escape()
          |> Phoenix.HTML.safe_to_string()
          |> String.trim()

        text(conn, string_to_render)
    end
  end

  def html_table(conn, %{"id" => id}) do
    case Lines.get_collection_with_assocs(id) do
      nil ->
        conn
        |> put_flash(:error, "Collection not found")
        |> redirect(to: ~p"/collections")

      collection ->
        chunk_groups = get_chunk_groups(collection.lines)

        string_to_render =
          ExportComponents.html_table(%{chunk_groups: chunk_groups})
          |> Phoenix.HTML.html_escape()
          |> Phoenix.HTML.safe_to_string()
          |> String.trim()

        text(conn, string_to_render)
    end
  end

  def markdown_table(conn, %{"id" => id}) do
    case Lines.get_collection_with_assocs(id) do
      nil ->
        conn
        |> put_flash(:error, "Collection not found")
        |> redirect(to: ~p"/collections")

      collection ->
        chunk_groups = get_chunk_groups(collection.lines)

        string_to_render =
          ExportComponents.markdown_table(%{chunk_groups: chunk_groups})
          |> Phoenix.HTML.html_escape()
          |> Phoenix.HTML.safe_to_string()
          |> String.trim()

        # |> IO.inspect()
        text(conn, string_to_render)
    end
  end

  def markdown_dl(conn, %{"id" => id}) do
    case Lines.get_collection_with_assocs(id) do
      nil ->
        conn
        |> put_flash(:error, "Collection not found")
        |> redirect(to: ~p"/collections")

      collection ->
        chunk_groups = get_chunk_groups(collection.lines)

        string_to_render =
          ExportComponents.markdown_dl(%{chunk_groups: chunk_groups})
          |> Phoenix.HTML.html_escape()
          |> Phoenix.HTML.safe_to_string()
          |> String.trim()

        # |> IO.inspect()
        text(conn, string_to_render)
    end
  end
end

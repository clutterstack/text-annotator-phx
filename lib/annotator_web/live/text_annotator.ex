defmodule AnnotatorWeb.TextAnnotator do
  use AnnotatorWeb, :live_view
  alias Annotator.Lines
  alias Annotator.Lines.Line
  import AnnotatorWeb.AnnotatorComponents
  require Logger


  def mount(%{"id" => id}, _session, socket) do
    case Lines.get_collection_with_lines(id) do
      nil ->
        Logger.info("in textannotator, no collection matched id")
        {:ok,
          socket
          |> put_flash(:error, "Collection not found")
          |> push_navigate(to: ~p"/collections")}

      collection ->
        # Logger.info("in textannotator, check lines: #{inspect collection.lines}")
        {:ok, assign(socket,
          collection: collection,
          lines: collection.lines,
          editing: nil,
          selection: nil
        )}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      collection: nil,
      lines: [%Line{line_number: 0, content: ""}],
      editing: nil,
      selection: nil,
      form: to_form(%{"name" => ""})
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl">
      <.modal :if={!@collection} id="collection-name-modal" show={true}>
        <.simple_form for={@form} phx-submit="create_collection">
          <.input field={@form[:name]} label="Collection Name" required />
          <:actions>
            <.button phx-disable-with="Creating...">Create Collection</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <div class="space-y-8 py-8">
        <.anno_grid
          mode="author"
          lines={@lines}
          editing={@editing}
          selection={@selection}
        >
          <:col name="line-span" label="Chunk lines" editable={false} deletable={false}>
          </:col>
          <:col name="line-num" label="Line" editable={false} deletable={false}>
          </:col>
          <:col name="content" label="Content" editable={true} deletable={true}>
          </:col>
          <:col name="note" label="Note" editable={true} deletable={false}>
          </:col>
        </.anno_grid>
      </div>
    </div>
    """
  end

  def handle_event("start_edit", %{"row_index" => row_index_str, "col_index" => col_index_str}, socket) do

    Logger.info("in start_edit handler")
    Logger.info("row_index: #{row_index_str} is_binary(row_index_str)? #{is_binary(row_index_str)}")
    case col_index_str do
      # Content column
      "2" ->
        Logger.info("start_edit in content cell; should start editing {#{row_index_str}, #{col_index_str}}")
        # Logger.info("check line.content: #{line.content}")
        {:noreply, assign(socket, editing: {row_index_str, col_index_str})}

      # Note column
      "3" ->
        Logger.info("start_edit in note cell; at row_index_str {#{row_index_str}} and col_index_str {#{col_index_str}}")
        {:noreply, assign(socket, editing: {row_index_str, col_index_str})}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    Logger.info("cancel_edit handler triggered")
    {:noreply, assign(socket,
      editing: nil)}
  end

  def handle_event("cancel_selection", _params, socket) do
    Logger.info("cancel_selection handler triggered")
    {:noreply, assign(socket, selection: nil)}
  end

  def handle_event("update_cell", %{"row_index" => row_index, "col_index" => "2", "value" => value}, socket) do
    Logger.info("is_binary(row_index)? #{is_binary(row_index)}")
    row_num = if is_binary(row_index), do: String.to_integer(row_index), else: row_index
    # collection_id = socket.assigns.collection.id
    line = Enum.at(socket.assigns.lines, row_num)
    handle_content_update(socket, line, value)
  end

  # # Add a new event handler for when note editing is complete:
  # def handle_event("update_cell", %{"row_index" => _row_index, "col_index" => "3", "value" => value}, socket) do
  #   case socket.assigns.editing do
  #     nil ->
  #       {:noreply, socket}

  #     {row_index, "3"} ->
  #       # Find the chunk for this row
  #       case get_chunk_for_row(socket.assigns.chunks, row_index) do
  #         nil ->
  #           {:noreply, socket |> put_flash(:error, "No chunk found")}

  #         chunk ->
  #           # Get line IDs through chunk_lines association
  #           line_ids = Enum.map(chunk.chunk_lines, & &1.line_id)

  #           case Lines.update_chunk(chunk, line_ids, value) do
  #             {:ok, _updated} ->
  #               {:noreply, assign(socket,
  #                 editing: nil
  #               )}

  #             {:error, changeset} ->
  #               {:noreply, socket |> put_flash(:error, error_to_string(changeset))}
  #           end
  #       end
  #   end
  # end

  def handle_event("delete_line", %{}, socket) do
    row_index = String.to_integer(elem(socket.assigns.editing, 0))
    line = Enum.at(socket.assigns.lines, row_index)
    collection_id = socket.assigns.collection.id

    # Don't delete if it's the last line
    case Lines.validate_line_deletion(collection_id) do
      :ok ->
        case Lines.delete_line(collection_id, line.id) do
          {:ok, _deleted_line} ->
            # Refresh collection data
            collection = Lines.get_collection_with_lines(collection_id)

            {:noreply, assign(socket,
              collection: collection,
              lines: collection.lines,
              editing: nil,
              # Clear selection if the deleted line was part of it
              selection: clear_selection_if_needed(socket.assigns.selection, line.id)
            )}

          {:error, reason} ->
            {:noreply,
              socket
              |> put_flash(:error, "Failed to delete line: #{inspect(reason)}")
              |> assign(editing: nil)}
        end

      {:error, reason} ->
        {:noreply,
          socket
          |> put_flash(:error, reason)
          |> assign(editing: nil)}
    end
  end

  def handle_event("rechunk", %{}, socket) do
    Logger.info("socket.assigns.selection: " <> inspect socket.assigns.selection)
    %{start_line: chunk_start, end_line: chunk_end} = socket.assigns.selection
    collection_id = socket.assigns.collection.id
    Logger.info("are chunk_start and chunk_end binaries? chunk_start: " <> (inspect is_binary(chunk_start)) <> "; " <> (inspect is_binary(chunk_end)))

    case Lines.ensure_chunk(collection_id, chunk_start, chunk_end) do
      {:ok, _} ->
        collection = Lines.get_collection_with_lines(collection_id)
        {:noreply, socket
          |> assign(
            collection: collection,
            lines: collection.lines,
            selection: nil
          )}

      {:error, reason} ->
        {:noreply, socket
          |> put_flash(:error, error_to_string(reason))
          |> assign(selection: nil)}
    end
  end

  # def handle_event("toggle_line_selection", %{"line" => line_number}, socket) do
  #   line_number = String.to_integer(line_number)

  #   selection = case socket.assigns.selection do
  #     nil ->
  #       # Start new selection
  #       %{start_line: line_number, end_line: line_number}

  #     %{start_line: start_line} = current_selection ->
  #       if line_number == start_line do
  #         # Clicking the start line again clears selection
  #         nil
  #       else
  #         # Extend selection to clicked line
  #         %{current_selection | end_line: line_number}
  #       end
  #   end

  #   {:noreply, assign(socket, selection: selection)}
  # end

  def handle_event("start_selection", %{"start" => start_line, "end" => end_line}, socket) do
    {:noreply, assign(socket, selection: %{
      start_line: start_line,
      end_line: end_line
    })}
  end

  def handle_event("update_selection", %{"start" => start_line, "end" => end_line}, socket) do
    Logger.info("updating line selection to #{start_line} - #{end_line}")
    {:noreply, assign(socket, selection: %{
      start_line: start_line,
      end_line: end_line
    })}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, selection: nil)}
  end

  def handle_event("create_collection", %{"name" => name}, socket) do
    case Lines.create_collection(%{name: name}) do
      {:ok, collection} ->
        {:ok, line} = Lines.add_line(collection.id, %{
          line_number: 0,
          content: "",
        })

        lines = [line]
        chunks = []

        {:noreply,
          socket
          |> assign(
            collection: collection,
            lines: lines,
            chunks: chunks,
            editing: {"0", "2"}, # Start in edit mode for content
            edit_text: "",
            selection: nil
          )
          |> put_flash(:info, "Collection created successfully")}

      {:error, changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, error_to_string(changeset))
          |> assign(form: to_form(Map.put(socket.assigns.form.data, "name", name)))}
    end
  end

  defp handle_content_update(socket, line, value) do
    case Lines.update_line!(socket.assigns.collection.id, line.line_number, :content, value) do
      {:ok, _} ->
        # Get fresh data since content updates might split lines
        collection = Lines.get_collection_with_lines(socket.assigns.collection.id)
        {:noreply, assign(socket,
          collection: collection,
          lines: collection.lines,
          editing: nil
        )}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update line: #{inspect(reason)}")
         |> assign(editing: nil)}
    end
  end

  defp clear_selection_if_needed(nil, _line_id), do: nil
  defp clear_selection_if_needed(selection, line_id) do
    if line_id in line_id_range(selection) do
      nil
    else
      selection
    end
  end

  defp line_id_range(%{start_line: start_id, end_line: end_id}) do
    Range.new(min(start_id, end_id), max(start_id, end_id))
  end

  defp error_to_string(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, "; ")}" end)
    |> Enum.join("\n")
  end
end

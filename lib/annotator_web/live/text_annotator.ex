defmodule AnnotatorWeb.TextAnnotator do
  use AnnotatorWeb, :live_view
  alias Annotator.Lines
  alias Annotator.Lines.{Line, Chunk}
  import AnnotatorWeb.AnnotatorComponents
  require Logger
  alias Annotator.Repo


  def mount(%{"id" => id}, _session, socket) do
    case Lines.get_collection_with_lines(id) do
      nil ->
        {:ok,
          socket
          |> put_flash(:error, "Collection not found")
          |> push_navigate(to: ~p"/collections")}

      collection ->
        chunks = Lines.list_chunks(collection.id)
        lines = collection.lines |> ensure_one_line()

        {:ok, assign(socket,
          collection: collection,
          lines: lines,
          chunks: chunks,
          focused_cell: {0, 1},
          editing: nil,
          selection: nil,
          active_chunk: nil
        )}
    end
  end

  def mount(_params, _session, socket) do
    # New collection - no chunks yet
    {:ok, assign(socket,
      collection: nil,
      lines: [%Line{line_number: 0, content: ""}],
      chunks: [],
      focused_cell: {0, 1},
      editing: nil,
      selection: nil,
      active_chunk: nil,
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
          id="annotated-content"
          rows={@lines}
          chunks={@chunks}
          editing={@editing}
          selection={@selection}
          row_click={fn row_index, col, col_index ->
            JS.push("click_edit", value: %{row_index: to_string(row_index), col_index: to_string(col_index)})
          end}
        >
          <:col :let={line} name="line-num" label="#" editable={false}>
            <%= line.line_number %>
          </:col>
          <:col :let={line} name="content" label="Content" editable={true}>
            <pre class="whitespace-pre-wrap"><code><%= line.content %></code></pre>
          </:col>
          <:col :let={line} name="note" label="Note" editable={true}>
            <div class="text-gray-400">No note</div>
          </:col>
        </.anno_grid>
      </div>
    </div>
    """
  end

  # Fix click handling
  def handle_event("click_edit", %{"row_index" => row_index_str, "col_index" => col_index_str}, socket) do
    Logger.info("in click_edit handler")
    Logger.info("row_index: #{row_index_str} is_binary(row_index_str)? #{is_binary(row_index_str)}")

    row_index = String.to_integer(row_index_str)
    col_index = String.to_integer(col_index_str)
    line = Enum.at(socket.assigns.lines, row_index)

    case col_index_str do
      # Content column
      "1" ->
        Logger.info("click_edit in content cell; should start editing {#{row_index}, #{col_index}}")
        Logger.info("check line.content: #{line.content}")
        {:noreply, assign(socket,
          editing: {row_index_str, col_index_str},
          edit_text: line.content || ""
        )}

      # Note column
      "2" ->
        Logger.info("click_edit in note cell; should call handle_note_click with row_index_str {#{row_index_str}}")

        handle_note_click(socket, line, row_index_str)

      _ ->
        {:noreply, socket}
    end
  end


  def handle_event("update_cell", %{"row_index" => row_index, "col_index" => "1", "value" => value}, socket) do
    Logger.info("is_binary(row_index)? #{is_binary(row_index)}")
    row_num = if is_binary(row_index), do: String.to_integer(row_index), else: row_index
    # collection_id = socket.assigns.collection.id
    line = Enum.at(socket.assigns.lines, row_num)
    handle_content_update(socket, line, value)
  end

  # Add a new event handler for when note editing is complete:
  def handle_event("update_cell", %{"row_index" => _row_index, "col_index" => "2", "value" => value}, socket) do
    case socket.assigns.selection do
      %{chunk_id: chunk_id} when not is_nil(chunk_id) ->
        # Updating existing chunk
        case Lines.update_chunk(
          Repo.get!(Chunk, chunk_id),
          get_selected_line_ids(socket.assigns.selection, socket.assigns.lines),
          value
        ) do
          {:ok, _chunk} ->
            chunks = Lines.list_chunks(socket.assigns.collection.id)
            {:noreply, assign(socket,
              chunks: chunks,
              editing: nil,
              selection: nil,
              active_chunk: nil
            )}

          {:error, changeset} ->
            {:noreply,
              socket
              |> put_flash(:error, "Error updating note: #{error_to_string(changeset)}")
              |> assign(editing: nil)}
        end

      _ ->
        # Creating new chunk
        case Lines.create_chunk(
          socket.assigns.collection.id,
          get_selected_line_ids(socket.assigns.selection, socket.assigns.lines),
          value
        ) do
          {:ok, _chunk} ->
            chunks = Lines.list_chunks(socket.assigns.collection.id)
            {:noreply, assign(socket,
              chunks: chunks,
              editing: nil,
              selection: nil,
              active_chunk: nil
            )}

          {:error, changeset} ->
            {:noreply,
              socket
              |> put_flash(:error, "Error creating note: #{error_to_string(changeset)}")
              |> assign(editing: nil)}
        end
    end
  end

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
            chunks = Lines.list_chunks(collection_id)

            {:noreply, assign(socket,
              collection: collection,
              lines: collection.lines,
              chunks: chunks,
              editing: nil,
              # Clear selection if the deleted line was part of it
              selection: clear_selection_if_needed(socket.assigns.selection, line.id),
              # Clear active chunk if it was related to the deleted line
              active_chunk: clear_active_chunk_if_needed(socket.assigns.active_chunk, chunks, line.id)
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

  def handle_event("create_collection", %{"name" => name}, socket) do
    case Lines.create_collection(%{name: name}) do
      {:ok, collection} ->
        # Save initial empty line
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
            editing: nil,
            selection: nil,
            active_chunk: nil
          )
          |> put_flash(:info, "Collection created successfully")}

      {:error, changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, error_to_string(changeset))
          |> assign(form: to_form(Map.put(socket.assigns.form.data, "name", name)))}
    end
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, selection: nil, active_chunk: nil)}
  end

  def handle_event("split_chunk", %{"chunk_id" => chunk_id, "line_number" => line_number}, socket) do
    case Lines.split_chunk(chunk_id, line_number) do
      {:ok, {_first, _second}} ->
        chunks = Lines.list_chunks(socket.assigns.collection.id)
        {:noreply, assign(socket, chunks: chunks)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error splitting chunk: #{inspect(reason)}")}
    end
  end

  def handle_event("merge_chunks", %{"chunk1_id" => id1, "chunk2_id" => id2}, socket) do
    case Lines.merge_chunks(id1, id2) do
      {:ok, _merged} ->
        chunks = Lines.list_chunks(socket.assigns.collection.id)
        {:noreply, assign(socket, chunks: chunks)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error merging chunks: #{inspect(reason)}")}
    end
  end
  defp handle_note_click(socket, line, row_index_str) do
    Logger.info("inside handle_note_click")
    Logger.info("row_index_str: #{row_index_str} is_binary(row_index_str)? #{is_binary(row_index_str)}")

    case {socket.assigns.selection, get_chunk_for_line(socket.assigns.chunks, line.id)} do
      {nil, %Chunk{} = chunk} ->
        # Clicking an existing chunk - start editing it
        Logger.info("selection is nil and get_chunk_for_line returned a chunk")

        {:noreply, assign(socket,
          active_chunk: chunk.id,
          editing: {row_index_str, "2"},  # Start editing the note cell
          edit_text: chunk.note,
          selection: %{
            start_line: line.id,
            end_line: line.id,
            note: chunk.note,
            chunk_id: chunk.id
          }
        )}

      {nil, nil} ->
        Logger.info("selection is nil and get_chunk_for_line returned nil")

        # Starting a new selection
        {:noreply, assign(socket,
          editing: {row_index_str, "2"},  # Start editing the note cell
          edit_text: "",
          selection: %{
            start_line: line.id,
            end_line: line.id,
            note: "",
            chunk_id: nil
          }
        )}

      {selection, _} ->
        Logger.info("selection is something and it's not checking for a chunk")

        # Expanding existing selection
        {:noreply, assign(socket,
          selection: %{selection | end_line: line.id}
        )}
    end
  end

  defp ensure_one_line([]), do: [%Line{line_number: 0, content: ""}]
  defp ensure_one_line(lines), do: lines

  defp get_chunk_for_line(chunks, line_id) do
    Enum.find(chunks, fn chunk ->
      Enum.any?(chunk.chunk_lines, fn cl -> cl.line_id == line_id end)
    end)
  end

  defp handle_content_update(socket, line, value) do
    case Lines.update_line!(socket.assigns.collection.id, line.line_number, :content, value) do
      {:ok, _} ->
        # Get fresh data since content updates might split lines
        collection = Lines.get_collection_with_lines(socket.assigns.collection.id)
        chunks = Lines.list_chunks(collection.id)
        {:noreply, assign(socket,
          collection: collection,
          lines: collection.lines,
          chunks: chunks,
          editing: nil
        )}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update line: #{inspect(reason)}")
         |> assign(editing: nil)}
    end
  end

  # Add helper function to get line IDs in selection range:
  defp get_selected_line_ids(%{start_line: start_id, end_line: end_id}, lines) do
    lines
    |> Enum.sort_by(& &1.line_number)
    |> Enum.filter(fn line ->
      line.id >= min(start_id, end_id) and line.id <= max(start_id, end_id)
    end)
    |> Enum.map(& &1.id)
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

  defp clear_active_chunk_if_needed(nil, _chunks, _line_id), do: nil
  defp clear_active_chunk_if_needed(chunk_id, chunks, line_id) do
    chunk = Enum.find(chunks, & &1.id == chunk_id)
    if chunk && Enum.any?(chunk.chunk_lines, & &1.line_id == line_id) do
      nil
    else
      chunk_id
    end
  end
end

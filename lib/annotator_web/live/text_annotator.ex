defmodule AnnotatorWeb.TextAnnotator do
  use AnnotatorWeb, :live_view
  alias Annotator.Lines
  alias Annotator.Lines.{Line, Chunk}
  import AnnotatorWeb.AnnotatorComponents
  require Logger


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
          editing: nil,
          edit_text: "",
          selection: nil,
          active_chunk: nil
        )}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      collection: nil,
      lines: [%Line{line_number: 0, content: ""}],
      chunks: [],
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
          mode="author"
          lines={@lines}
          chunks={@chunks}
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
      editing: nil,
      active_chunk: nil)}
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

  # Add a new event handler for when note editing is complete:
  def handle_event("update_cell", %{"row_index" => _row_index, "col_index" => "3", "value" => value}, socket) do
    case socket.assigns.editing do
      nil ->
        {:noreply, socket}

      {row_index, "3"} ->
        # Find the chunk for this row
        case get_chunk_for_row(socket.assigns.chunks, row_index) do
          nil ->
            {:noreply, socket |> put_flash(:error, "No chunk found")}

          chunk ->
            # Get line IDs through chunk_lines association
            line_ids = Enum.map(chunk.chunk_lines, & &1.line_id)

            case Lines.update_chunk(chunk, line_ids, value) do
              {:ok, _updated} ->
                {:noreply, assign(socket,
                  chunks: Lines.list_chunks(socket.assigns.collection.id),
                  editing: nil
                )}

              {:error, changeset} ->
                {:noreply, socket |> put_flash(:error, error_to_string(changeset))}
            end
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

  def handle_event("rechunk", %{}, socket) do
    # Find boundaries of new chunk
    %{start_line: chunk_start, end_line: chunk_end} = socket.assigns.selection
    Logger.info("chunk_start; chunk_end: " <> to_string(chunk_start) <> ", " <> to_string(chunk_end))
    Logger.info("collection id: " <> inspect socket.assigns.collection.id)
    # find chunks that currently contain the line boundaries
    first_chunk_id = Lines.get_chunk_id_by_line(socket.assigns.collection.id, chunk_start)
    last_chunk_id = Lines.get_chunk_id_by_line(socket.assigns.collection.id, chunk_end)
    Logger.info("first chunk; last chunk: #{inspect first_chunk_id}, #{inspect last_chunk_id}")
    # split first chunk at starting line
    split_chunk({first_chunk_id, chunk_start}, socket)
    # split last chunk at ending line
    split_chunk({last_chunk_id, chunk_end}, socket)
    # get ids of chunks where the start and end lines now sit
    new_first_chunk_id = Lines.get_chunk_id_by_line(socket.assigns.collection.id, chunk_start)
    new_last_chunk_id = Lines.get_chunk_id_by_line(socket.assigns.collection.id, chunk_end)
    # merge all chunks between starting and ending lines
    merge_chunks({new_first_chunk_id, new_last_chunk_id}, socket)
    ## TODO: merge notes?


    {:noreply, socket}
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

  defp merge_chunks({first_chunk_id, last_chunk_id}, socket) do
    case Lines.merge_chunks(first_chunk_id, last_chunk_id) do
      {:ok, _merged} ->
        chunks = Lines.list_chunks(socket.assigns.collection.id)
        {:noreply, assign(socket, chunks: chunks)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error merging chunks: #{inspect(reason)}")}
    end
  end

  defp split_chunk({chunk_id, line_number}, socket) do
    case Lines.split_chunk(chunk_id, line_number) do
      {:ok, {_first, _second}} ->
        chunks = Lines.list_chunks(socket.assigns.collection.id)
        {:noreply, assign(socket, chunks: chunks)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error splitting chunk: #{inspect(reason)}")}
    end
  end


  defp find_containing_chunk(line_number, chunks) do
    chunk = Enum.find(chunks, fn chunk ->
      chunk.chunk_lines
      |> IO.inspect()
      |> Enum.any?(fn line ->
        line.line_number == line_number
      end)
      |> IO.inspect()
    end)
    chunk.id
  end

  defp get_chunk_for_row(chunks, row_index) do
    # This needs to match how you're organizing chunks in your grid
    # You might need to adjust based on your exact grid structure
    Enum.at(chunks, String.to_integer(row_index))
  end

  defp merge_chunks_at_selection(socket) do
    case socket.assigns.selection do
      nil ->
        socket |> put_flash(:error, "Select lines to merge at")

      selection ->
        # Find chunks that include or are adjacent to selection point
        case find_mergeable_chunks(selection, socket.assigns.chunks) do
          {chunk1, chunk2} ->
            case Lines.merge_chunks(chunk1.id, chunk2.id) do
              {:ok, _merged} ->
                socket
                |> assign(
                  chunks: Lines.list_chunks(socket.assigns.collection.id),
                  selection: nil
                )
                |> put_flash(:info, "Chunks merged")

              {:error, reason} ->
                socket |> put_flash(:error, "Could not merge chunks: #{inspect(reason)}")
            end

          :no_mergeable_chunks ->
            socket |> put_flash(:error, "No chunks to merge at selection")

          :not_adjacent ->
            socket |> put_flash(:error, "Can only merge adjacent chunks")
        end
    end
  end

  defp find_mergeable_chunks(selection, chunks) do
    # Sort chunks by their first line number
    sorted_chunks =
      chunks
      |> Enum.sort_by(fn chunk ->
        # Fix: Don't assume line association is loaded, explicitly get through chunk_lines
        chunk.chunk_lines
        |> Enum.map(& &1.line.line_number)
        |> Enum.min()
      end)

    # Find chunks around the selection point
    case Enum.chunk_every(sorted_chunks, 2, 1, :discard) do
      [] ->
        :no_mergeable_chunks

      pairs ->
        # Find a pair where the selection point is at their boundary
        Enum.find_value(pairs, :not_adjacent, fn [chunk1, chunk2] ->
          # Fix: Get line numbers through chunk_lines
          chunk1_lines = Enum.map(chunk1.chunk_lines, & &1.line.line_number)
          chunk2_lines = Enum.map(chunk2.chunk_lines, & &1.line.line_number)

          chunk1_max = Enum.max(chunk1_lines)
          chunk2_min = Enum.min(chunk2_lines)

          if selection.start_line in [chunk1_max, chunk2_min] do
            {chunk1, chunk2}
          end
        end)
    end
  end

  defp clear_selection(socket) do
    assign(socket,
      selection: nil,
      active_chunk: nil
    )
  end

  defp get_focused_line_number(socket) do
    case socket.assigns.focused_cell do
      {row_index, 0} -> # First column (line numbers)
        case Enum.at(socket.assigns.chunk_groups, row_index) do
          {_chunk, [first_line | _]} -> first_line.line_number
          _ -> nil
        end
      _ -> nil
    end
  end

  defp ensure_one_line([]), do: [%Line{line_number: 0, content: ""}]
  defp ensure_one_line(lines), do: lines

  # defp get_chunk_for_line(chunks, line_id) do
  #   Enum.find(chunks, fn chunk ->
  #     Enum.any?(chunk.chunk_lines, fn cl -> cl.line_id == line_id end)
  #   end)
  # end

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
  defp get_selected_line_ids(%{start_line: start_line, end_line: end_line}, lines) do
    lines
    |> Enum.filter(fn line ->
      line.line_number >= min(start_line, end_line) and
      line.line_number <= max(start_line, end_line)
    end)
    |> Enum.map(& &1.id)
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

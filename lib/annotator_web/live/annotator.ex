defmodule AnnotatorWeb.TextAnnotator do
  use Phoenix.LiveView
  alias Annotator.TextChunker
  alias AnnotatorWeb.AnnotatorComponents
  require Logger

  defmodule TextChunk do
    defstruct [:id, :text, :highlight_start, :highlight_end]
  end

  defmodule Annotation do
    defstruct [:id, :chunk_id, :text, :annotation, :start_pos, :end_pos]
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      chunks: [%TextChunk{id: 0, text: "Initial text\nwith multiple\nlines of content\nand more lines\nhere", highlight_start: nil, highlight_end: nil}],
      annotations: [],
      selected_text: "",
      selected_chunk_id: nil,
      selection_start: nil,
      selection_length: 0,
      editing_id: nil,
      next_id: 1,
      next_annotation_id: 0
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto mt-10">
      <%= for chunk <- @chunks do %>
        <div class="mb-8">
          <%= if @editing_id == chunk.id do %>
            <form phx-submit={"save_edit_#{chunk.id}"}>
              <textarea name="text" rows="8" class="w-full p-2 border rounded font-mono"><%= chunk.text %></textarea>
              <button type="submit" class="mt-1 px-2 py-1 bg-green-500 text-white rounded text-sm">Save</button>
            </form>
          <% else %>
            <div class="relative p-2 whitespace-pre-wrap font-mono border rounded group"><div id={"chunk-#{chunk.id}"} phx-hook="SelectText"><%= if chunk.highlight_start do %><AnnotatorComponents.text_with_highlights chunk={chunk} /><% else %><%= chunk.text %><% end %></div>
            <button class="invisible group-hover:visible absolute top-2 right-2 px-2 py-1 bg-blue-500 text-white rounded text-sm"
                    phx-click="edit_chunk"
                    phx-value-id={chunk.id}>
              Edit
              </button></div>
          <% end %>
        </div>
        <div  class="mb-8">
          <p> HEre will be the annotations for chunk-<%= chunk.id %></p>
          <%= for annotation <- chunk_annotations(@annotations, chunk.id) do %>
            <div class="mt-2 p-2 border-l-4 border-blue-500 bg-blue-50">
              <p class="text-sm text-gray-600">Annotation for: "<%= annotation.text %>"</p>
              <p class="mt-1"><%= annotation.annotation %></p>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @selected_text != "" do %>
        <div class="fixed bottom-4 right-4 bg-white p-4 shadow-lg rounded-lg border">
          <p class="mb-2">Selected: "<%= @selected_text %>"</p>
          <div class="space-y-2">
            <div>
              <textarea
                placeholder="Add your annotation here..."
                class="w-full p-2 border rounded"
                phx-keyup="update_draft_annotation"
                phx-key="Enter"
              ></textarea>
            </div>
            <div class="space-x-2">
              <button class="px-4 py-2 bg-blue-500 text-white rounded"
                      phx-click="split_at_selection">
                Split Here
              </button>
              <button class="px-4 py-2 bg-green-500 text-white rounded"
                      phx-click="save_annotation">
                Save Annotation
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end


  def handle_event("text_selected", %{"text" => text, "chunk_id" => chunk_id, "start_offset" => start_offset}, socket) do
    chunk_id = String.replace(chunk_id, "chunk-", "") |> String.to_integer()
    case Enum.find(socket.assigns.chunks, &(&1.id == chunk_id)) do
      nil ->
        {:error, :chunk_not_found}
      _chunk ->
        selection_start = start_offset # get_selection_position(Enum.find(socket.assigns.chunks, &(&1.id == chunk_id)).text, text)
        # Logger.info("in text_selected handler, selection_start is #{selection_start} and selection_length is #{String.length(text)}")
        {:noreply, assign(socket,
          selected_text: text,
          selected_chunk_id: chunk_id,
          selection_start: selection_start,
          selection_length: String.length(text),
          draft_annotation: nil
        )}
      end
  end

  def handle_event("split_at_selection", _, socket) do
    %{selected_chunk_id: chunk_id, selection_start: selection_start, selection_length: selection_length, chunks: chunks} = socket.assigns
    chunk = Enum.find(chunks, &(&1.id == chunk_id))
    Logger.info("In split_at_selection handler: chunk is #{inspect chunk}")

    split_chunk = TextChunker.split_text_chunk(chunk.text, selection_start, selection_length)
    Logger.info("split_chunk: #{inspect split_chunk}")

    # Keep track of the index where we need to insert the new chunks
    original_index = Enum.find_index(chunks, &(&1.id == chunk_id))

    # Process the split chunks while preserving order
    new_split_chunks = split_chunk
      |> Enum.with_index()
      |> Enum.map(fn {{text, start_position}, index} ->
        %TextChunk{
          id: socket.assigns.next_id + index,
          text: text
          # Don't do highlights for now. It kind of works, but
          # I'd like to do editable chunks before highlights and
          # keeping track of the position of the highlight after
          # editing is fun I don't want to have right now
          # highlight_start: start_position,
          # highlight_end: if(start_position, do: start_position + selection_length, else: nil)
        }
      end)
      |> Enum.reject(&(String.trim(&1.text) == ""))

    # Reconstruct the chunks list with the new chunks in the correct position
    new_chunks = chunks
      |> List.delete_at(original_index)  # Remove the original chunk
      |> List.insert_at(original_index, new_split_chunks) # Insert new chunks at the same position
      |> List.flatten()

    {:noreply, assign(socket,
      chunks: new_chunks,
      selected_text: "",
      selected_chunk_id: nil,
      next_id: socket.assigns.next_id + 3
    )}
  end

  def handle_event("edit_chunk", %{"id" => id}, socket) do
    {:noreply, assign(socket, editing_id: String.to_integer(id))}
  end

  def handle_event("save_edit_" <> id, %{"text" => text}, socket) do
    chunk_id = String.to_integer(id)
    chunks = Enum.map(socket.assigns.chunks, fn chunk ->
      if chunk.id == chunk_id do
        %{chunk | text: text}
      else
        chunk
      end
    end)
    {:noreply, assign(socket, chunks: chunks, editing_id: nil)}
  end


  def handle_event("update_draft_annotation", %{"value" => value}, socket) do
    {:noreply, assign(socket, draft_annotation: value)}
  end

  def handle_event("save_annotation", _, socket) do
    %{selected_chunk_id: chunk_id, selected_text: text, draft_annotation: annotation} = socket.assigns

    if annotation do
      new_annotation = %Annotation{
        id: socket.assigns.next_annotation_id,
        chunk_id: chunk_id,
        text: text,
        annotation: annotation,
        start_pos: 0,
        end_pos: 0
      }

      {:noreply, assign(socket,
        annotations: [new_annotation | socket.assigns.annotations],
        selected_text: "",
        selected_chunk_id: nil,
        draft_annotation: nil,
        next_annotation_id: socket.assigns.next_annotation_id + 1
      )}
    else
      {:noreply, socket}
    end
  end

  # Helper functions

  # defp split_chunk_at_selection(text, selection_start, selection_length) do
    # Gives a tuple containing the text before the split, the
    # new chunk, the text after the split, and a tuple with start position
    # and length of the highlighted text.

    # Usage: {pre, selected_line, post, highlight_range} = split_chunk_at_selection(chunk.text, selected_text)

    #   IO.inspect(text)
    #   case String.trim(text) do
    #     # if there's no text in the chunk??
    #     "" -> {}
    #     _ ->

    #       # Find line boundaries
    #       lines = String.split(text, "\n")
    #       {pre_lines, selected_and_post} = Enum.split_while(lines, fn line ->
    #         not String.contains?(line, selected)
    #       end)

    #       [selected_line | post_lines] = selected_and_post

    #       {
    #         Enum.join(pre_lines, "\n"),
    #         selected_line,
    #         Enum.join(post_lines, "\n"),
    #         {selection_start, selection_length}
    #       }
    #   end
    # end

  # get the annotations for this text chunk
  defp chunk_annotations(annotations, chunk_id) do
    Enum.filter(annotations, &(&1.chunk_id == chunk_id))
  end

end

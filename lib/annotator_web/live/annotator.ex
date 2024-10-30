defmodule AnnotatorWeb.TextAnnotator do
  use Phoenix.LiveView
  require Logger

  defmodule TextChunk do
    defstruct [:id, :text, :highlight_start, :highlight_end]
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      chunks: [%TextChunk{id: 0, text: "Initial text\nwith multiple\nlines of content\nand more lines\nhere", highlight_start: nil, highlight_end: nil}],
      selected_text: "",
      selected_chunk_id: nil
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto mt-10">
      <%= for chunk <- @chunks do %>
        <div class="mb-4">
          <div class="p-2 whitespace-pre-wrap font-mono border rounded"
               id={"chunk-#{chunk.id}"}
               phx-hook="SelectText">
            <%= if chunk.highlight_start do %>
              <%= String.slice(chunk.text, 0, chunk.highlight_start) %>
              <span class="bg-yellow-200">
                <%= String.slice(chunk.text, chunk.highlight_start, chunk.highlight_end - chunk.highlight_start) %>
              </span>
              <%= String.slice(chunk.text, chunk.highlight_end..-1) %>
            <% else %>
              <%= chunk.text %>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @selected_text != "" do %>
        <div class="fixed bottom-4 right-4 bg-white p-4 shadow-lg rounded-lg border">
          <p class="mb-2">Selected: "<%= @selected_text %>"</p>
          <button class="px-4 py-2 bg-blue-500 text-white rounded"
                  phx-click="split_at_selection">
            Split Here
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("text_selected", %{"text" => text, "chunkId" => chunk_id}, socket) do
    {:noreply, assign(socket,
      selected_text: text,
      selected_chunk_id: String.replace(chunk_id, "chunk-", "") |> String.to_integer()
    )}
  end

  def handle_event("split_at_selection", _, socket) do
    %{selected_chunk_id: chunk_id, selected_text: selected_text, chunks: chunks} = socket.assigns
    chunk = Enum.find(chunks, &(&1.id == chunk_id))

    {pre, selected_line, post, highlight_range} = split_chunk_at_selection(chunk.text, selected_text)
    {highlight_start, highlight_length} = highlight_range

    new_chunks = chunks
      |> Enum.reject(&(&1.id == chunk_id))
      |> Kernel.++([
        %TextChunk{id: length(chunks), text: pre, highlight_start: nil, highlight_end: nil},
        %TextChunk{id: length(chunks) + 1, text: selected_line, highlight_start: highlight_start, highlight_end: highlight_start + highlight_length},
        %TextChunk{id: length(chunks) + 2, text: post, highlight_start: nil, highlight_end: nil}
      ])
      |> Enum.reject(&(String.trim(&1.text) == ""))
      |> Enum.sort_by(& &1.id)

    {:noreply, assign(socket, chunks: new_chunks, selected_text: "", selected_chunk_id: nil)}
  end

  defp split_chunk_at_selection(text, selected) do
    selection_start = :binary.match(text, selected) |> elem(0)

    # Find line boundaries
    lines = String.split(text, "\n")
    {pre_lines, selected_and_post} = Enum.split_while(lines, fn line ->
      not String.contains?(line, selected)
    end)

    [selected_line | post_lines] = selected_and_post

    # Calculate highlight position within the selected line
    highlight_start = :binary.match(selected_line, selected) |> elem(0)

    {
      Enum.join(pre_lines, "\n"),
      selected_line,
      Enum.join(post_lines, "\n"),
      {highlight_start, String.length(selected)}
    }
  end
end

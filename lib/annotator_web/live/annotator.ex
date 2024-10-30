defmodule AnnotatorWeb.TextAnnotator do
  use Phoenix.LiveView
  require Logger

  defmodule TextChunk do
    defstruct [:id, :text]
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      chunks: [%TextChunk{id: 0, text: "Initial text\nwith multiple\nlines of content\nand more lines\nhere"}],
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
            <%= chunk.text %>
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
    Logger.info("Selected text: #{text} in chunk #{chunk_id}")
    {:noreply, assign(socket,
      selected_text: text,
      selected_chunk_id: String.replace(chunk_id, "chunk-", "") |> String.to_integer()
    )}
  end

  def handle_event("split_at_selection", _, socket) do
    %{selected_chunk_id: chunk_id, selected_text: selected_text, chunks: chunks} = socket.assigns
    chunk = Enum.find(chunks, &(&1.id == chunk_id))

    {pre, selected, post} = split_chunk_at_selection(chunk.text, selected_text)

    new_chunks = chunks
      |> Enum.reject(&(&1.id == chunk_id))
      |> Kernel.++([
        %TextChunk{id: length(chunks), text: pre},
        %TextChunk{id: length(chunks) + 1, text: selected},
        %TextChunk{id: length(chunks) + 2, text: post}
      ])
      |> Enum.reject(&(String.trim(&1.text) == ""))
      |> Enum.sort_by(& &1.id)

    {:noreply, assign(socket, chunks: new_chunks, selected_text: "", selected_chunk_id: nil)}
  end

  defp split_chunk_at_selection(text, selected) do
    selection_start = :binary.match(text, selected) |> elem(0)
    selection_end = selection_start + String.length(selected)

    # Get text before selection
    text_before = String.slice(text, 0, selection_start)
    # Get selection
    selected_text = String.slice(text, selection_start, String.length(selected))
    # Get text after selection
    text_after = String.slice(text, selection_end..-1)

    # Find line boundaries
    pre_split = case :binary.matches(text_before, "\n") do
      [] -> 0
      matches -> elem(List.last(matches), 0) + 1
    end

    post_split = case :binary.match(text_after, "\n") do
      :nomatch -> String.length(text_after)
      {pos, _} -> pos
    end

    pre = String.slice(text, 0, pre_split)
    post = String.slice(text_after, post_split..-1)

    {pre, selected_text, post}
  end
end

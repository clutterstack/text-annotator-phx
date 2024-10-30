defmodule AnnotatorWeb.TextAnnotator do
  use Phoenix.LiveView
  require Logger

  defmodule Paragraph do
    defstruct [:id, :text]
  end

  defmodule Selection do
    defstruct [:id, :paragraph_id, :start, :end, :text]
  end

  defmodule Note do
    defstruct [:id, :selection_id, :text]
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      input_text: "",
      paragraphs: [],
      selections: [],
      notes: [],
      selected_text: "",
      annotation: ""
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto mt-10 flex flex-col md:flex-row">
      <div class="w-full md:w-1/2 pr-4 mb-4 md:mb-0">
        <form phx-submit="process_text">
          <textarea name="input_text" rows="10" class="w-full p-2 border rounded text-gray-800" placeholder="Paste your text here"><%= @input_text %></textarea>
          <button type="submit" class="mt-2 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">Process Text</button>
        </form>
        <div class="mt-4">
          <h2 class="text-lg font-semibold">Processed Text:</h2>
          <%= for p <- @paragraphs do %>
            <div id={"para-#{p.id}"} data-id={p.id} class="my-2 whitespace-pre-wrap" phx-hook="SelectText">
              <%= p.text %>
            </div>
          <% end %>
        </div>
      </div>
      <div class="w-full md:w-1/2 pl-4">
        <form phx-submit="add_annotation">
          <div class="mb-2">
            <label class="block text-sm font-medium text-gray-700">Selected Text:</label>
            <textarea readonly rows="2" class="w-full p-2 border rounded text-gray-800 bg-gray-100"><%= @selected_text %></textarea>
          </div>
          <div class="mb-2">
            <label class="block text-sm font-medium text-gray-700">Your Annotation:</label>
            <textarea name="annotation" rows="3" class="w-full p-2 border rounded text-gray-800" placeholder="Type your annotation here"><%= @annotation %></textarea>
          </div>
          <button type="submit" class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600 disabled:bg-gray-300 disabled:cursor-not-allowed" disabled={@selected_text == ""}>
            Add Annotation
          </button>
        </form>
        <div class="mt-4">
          <h2 class="text-lg font-semibold">Annotations:</h2>
          <%= for note <- @notes do %>
            <% selection = Enum.find(@selections, &(&1.id == note.selection_id)) %>
            <div class="mb-4 p-2 border rounded">
              <p class="font-italic">"<%= selection.text %>"</p>
              <p class="mt-1"><%= note.text %></p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("process_text", %{"input_text" => text}, socket) do
    paragraphs = text
    |> String.split(~r/\n{2,}/)
    |> Enum.with_index()
    |> Enum.map(fn {text, id} -> %Paragraph{id: id, text: text} end)

    {:noreply, assign(socket, paragraphs: paragraphs, input_text: text)}
  end

  def handle_event("text_selected", %{"text" => text, "paragraph_id" => paragraph_id}, socket) do
    {:noreply, assign(socket, selected_text: text, current_paragraph: String.to_integer(paragraph_id))}
  end

  def handle_event("add_annotation", %{"annotation" => annotation}, socket) do
    %{selections: selections, notes: notes, selected_text: selected_text, current_paragraph: current_paragraph} = socket.assigns

    if current_paragraph && selected_text != "" && annotation != "" do
      selection_start = :binary.match(Enum.at(socket.assigns.paragraphs, current_paragraph).text, selected_text) |> elem(0)

      new_selection = %Selection{
        id: length(selections),
        paragraph_id: current_paragraph,
        start: selection_start,
        end: selection_start + String.length(selected_text),
        text: selected_text
      }

      new_note = %Note{
        id: length(notes),
        selection_id: new_selection.id,
        text: annotation
      }

      {:noreply, assign(socket,
        selections: [new_selection | selections],
        notes: [new_note | notes],
        selected_text: "",
        annotation: ""
      )}
    else
      {:noreply, socket}
    end
  end
end

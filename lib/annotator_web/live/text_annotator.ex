defmodule AnnotatorWeb.TextAnnotator do
  use AnnotatorWeb, :live_view
  alias Annotator.Lines
  alias Annotator.Lines.Line
  import AnnotatorWeb.AnnotatorComponents
  import AnnotatorWeb.CoreComponents
  require Logger

  def mount(%{"id" => id}, _session, socket) do
    # Editing existing collection
    collection = Lines.get_collection_with_lines(id)
    {:ok, assign(socket,
      collection: collection,
      lines: collection.lines,
      focused_cell: {0, 1},
      editing: nil
    )}
  end

  def mount(_params, _session, socket) do
    # New collection
    {:ok, assign(socket,
      collection: nil,
      lines: [%Line{line_number: 0, content: "", note: ""}],
      focused_cell: {0, 1},
      editing: nil,
      form: to_form(%{"name" => ""})
    )}
  end

  def render(assigns) do
    ~H"""
    <.modal :if={!@collection} id="collection-name-modal" show={true}>
      <div class="space-y-6 py-4">
        <h2 class="text-lg font-semibold leading-7 text-zinc-900">
          New Collection
        </h2>

        <.form
          for={@form}
          phx-submit="create_collection"
          id="collection-form"
        >
          <.input type="text" field={@form[:name]} label="Collection Name" required />
          <div class="mt-6 flex justify-end gap-3">
            <.button phx-disable-with="Creating...">Start Annotating</.button>
          </div>
        </.form>
      </div>
    </.modal>


    <div class="mx-auto max-w-4xl">
      <%= if @collection do %>
        <div class="mb-4 flex justify-between items-center">
          <h1 class="text-2xl font-bold"><%= @collection.name %></h1>
          <.link navigate={~p"/collections"} class="text-zinc-600 hover:text-zinc-900">
            Back to Collections
          </.link>
        </div>
      <% end %>

      <.anno_grid
        id="this-annotated-content"
        rows={@lines}
        editing={@editing}
        row_click={fn row_index, col, col_index ->
          if col[:name] in ["content", "note"] && @editing == nil do
            JS.push("click_edit", value: %{row_index: row_index, col_index: col_index})
          end
        end}
      >
        <:col :let={line} name="line-num" label="#" editable={false}><%= line.line_number %></:col>
        <:col :let={line} name="content" label="Content" editable={true}>
          <pre class="whitespace-pre-wrap"><code><%= line.content %></code></pre>
        </:col>
        <:col :let={line} name="note" label="Note" editable={true}>
          <div><%= raw(Earmark.as_html!(line.note, breaks: true)) %></div>
        </:col>
      </.anno_grid>
    </div>
    """
  end

  def handle_event("create_collection", %{"name" => name}, socket) do
    case Lines.create_collection(%{name: name}) do
      {:ok, collection} ->
        # Save initial empty line
        {:ok, _line} = Lines.add_line(collection.id, %{
          line_number: 0,
          content: "",
          note: ""
        })

        {:noreply,
         socket
         |> assign(collection: collection, show_name_modal: false)
         |> put_flash(:info, "Collection created successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, error_to_string(changeset))
         |> assign(form: to_form(Map.put(socket.assigns.form.data, "name", name)))}
    end
  end


  def handle_event("click_edit", %{"row_index" => row_index, "col_index" => col_index}, socket) do
    Logger.info("click_edit handler. {row_index, col_index}: {#{row_index}, #{col_index}}")
    if socket.assigns.editing == nil do
      {:noreply, assign(socket, editing: {row_index, col_index})}
    else
      Logger.info("start_edit event but already editing")
      {:noreply, socket}
    end
  end

  # def handle_event("click_focus", %{"row_index" => row_index, "col_index" => col_index}, socket) do
  #   Logger.info("click_focus handler. {row_index, col_index}: {#{row_index}, #{col_index}}")
  #   {:noreply, assign(socket, focused_cell: {row_index, col_index})}
  # end


  def handle_event("cancel_edit", _params, socket) do
    Logger.info("cancel_edit handler triggered")
    {:noreply, assign(socket, editing: nil)}
  end

  # Handle cell focus from JS hook
  # def handle_event("cell_focused", %{"row" => row_index, "col" => col_index}, socket) do
  #   # Convert row_index to line_number if needed
  #   line = Enum.at(socket.assigns.lines, row_index)
  #   if line do
  #     {:noreply, assign(socket, focused_cell: {line.line_number, col_index})}
  #   else
  #     {:noreply, socket}
  #   end
  # end

  def handle_event("update_cell", %{"row_index" => row_index, "col_index" => col_index, "value" => new_value}, socket) do
    row_num = if is_binary(row_index), do: String.to_integer(row_index), else: row_index
    collection_id = socket.assigns.collection.id

    field = case col_index do
      "1" -> :content
      "2" -> :note
      _ -> nil
    end

    case field && Lines.update_line!(collection_id, row_num, field, new_value) do
      {:ok, _} ->
        # Refresh collection data
        collection = Lines.get_collection_with_lines(collection_id)
        {:noreply, assign(socket, lines: collection.lines, editing: nil)}

      {:error, reason} ->
        Logger.error("Failed to update line: #{inspect(reason)}")
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update line")
         |> assign(editing: nil)}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("delete_line", _params, socket) do
    row_num = elem(socket.assigns.editing, 0)
    collection_id = socket.assigns.collection.id

    case Lines.delete_line!(collection_id, row_num) do
      {:ok, _} ->
        collection = Lines.get_collection_with_lines(collection_id)
        {:noreply, assign(socket, lines: collection.lines, editing: nil)}

      {:error, reason} ->
        Logger.error("Failed to delete line: #{inspect(reason)}")
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete line")
         |> assign(editing: nil)}
    end
  end

  def create_data_grid(content) do
    String.split(content, "\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {line, index} ->
      %Annotator.Lines.Line{line_number: index, content: line, note: ""}
    end)
  end

  defp error_to_string(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.reduce("", fn {k, v}, acc ->
      joined_errors = Enum.join(v, "; ")
      "#{acc}#{k}: #{joined_errors}\n"
    end)
  end
end

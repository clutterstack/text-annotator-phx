defmodule AnnotatorWeb.TextAnnotator do
  use Phoenix.LiveView
  alias Annotator.DataGridSchema
  alias Phoenix.LiveView.JS
  import AnnotatorWeb.AnnotatorComponents
  require Logger

  def mount(_params, _session, socket) do
    Logger.info("TextAnnotator liveview mount -- all the assigns get reset when this happens")
    {:ok, assign(socket,
      lines: [%DataGridSchema.Line{id: "one", line_number: 0, content: "Here's some content", note: "Here's a note on row number 0"}, %DataGridSchema.Line{id: "two", line_number: 1, content: "Here's two content", note: "Here's a note on row number 1"}],
      focused_cell: {0, 1},  # {row, col} numbers for first row and the content column (first col is line number display)
      editing: nil  # nil or {id, :content|:note}
    )}
  end

  def render(assigns) do
    ~H"""
    <.anno_grid
      id="this-annotated-content"
      rows={@lines}
      editing={@editing}
      row_click={fn row_index, col, col_index ->
        if col[:name] in ["content", "note"] && @editing == nil do
          JS.push("click_edit", value: %{row_index: row_index, col_index: col_index})
        else
          JS.push("click_focus", value: %{row_index: row_index, col_index: col_index})
        end
    end}>
      <:col :let={line} name="line-num" label="#"><%= line.line_number %></:col>
      <:col :let={line} name="content" label="Content"><%= line.content %></:col>
      <:col :let={line} name="note" label="Note"><%= line.note %></:col>
    </.anno_grid>
    """
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

  def handle_event("click_focus", %{"row_index" => row_index, "col_index" => col_index}, socket) do
    Logger.info("click_focus handler. {row_index, col_index}: {#{row_index}, #{col_index}}")
    {:noreply, assign(socket, focused_cell: {row_index, col_index})}
  end

  def handle_event("prompt_save_changes", _params, socket) do
    Logger.info("TODO: add a prompt to save or abandon edits to the cell before blurring")
    {:noreply, socket}
  end

  # Handle the activate_cell event from the hook (triggered by Enter key)
  def handle_event("activate_cell", %{"row" => row_index, "col" => col_index}, socket) do
    Logger.info("activate_cell handler. Should be the same as click_edit. {row_index, col_index}: {#{row_index}, #{col_index}}")
    if socket.assigns.editing == nil do
      {:noreply, assign(socket, editing: {row_index, col_index})}
    else
      Logger.info("start_edit event but already editing")
      {:noreply, socket}
    end
  end


# def handle_event("activate_cell", %{"row" => row_index, "col" => col_index}, socket) do
#   # Find the line by index in the list
#   line = Enum.at(socket.assigns.lines, row_index)
#   # Get the column name based on index
#   col_name = case col_index do
#     0 -> "line-num"
#     1 -> "content"
#     2 -> "note"
#     _ -> nil
#   end

#   if line && col_name in ["content", "note"] do
#     {:noreply, assign(socket, editing: {line.line_number, col_name})}
#   else
#     {:noreply, socket}
#   end
# end

  def handle_event("cancel_edit", _params, socket) do
    Logger.info("cancel_edit handler triggered")
    {:noreply, assign(socket, editing: nil)}
  end

  # Handle cell focus from JS hook
  def handle_event("cell_focused", %{"row" => row_index, "col" => col_index}, socket) do
    # Convert row_index to line_number if needed
    line = Enum.at(socket.assigns.lines, row_index)
    if line do
      {:noreply, assign(socket, focused_cell: {line.line_number, col_index})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_cell", %{"row" => row_index, "col" => col_index, "value" => new_value}, socket) do
    Logger.info("update_cell handler called")
    # Find the line by index in the list
    line = Enum.at(socket.assigns.lines, row_index)
    # Get the column name based on index
    col_name = case col_index do
      1 -> "content"
      2 -> "note"
      _ -> nil
    end

    if line && col_name in ["content", "note"] do
      {:noreply, assign(socket, lines: lines.row_index.)}
    else
      {:noreply, socket}
    end
  end

  updated_items = List.update_at(socket.assigns.items, index, fn item ->
    Map.put(item, String.to_existing_atom(field), value)
  end)

# Handle content updates, including paste events
def handle_event("update_content", %{"line_number" => line_number, "content" => content}, socket) do
  Logger.info("Handling event update_content; line_number is #{line_number}")
  if String.contains?(content, "\n") do
    # Handle multi-line paste
    [first_line | new_lines] = String.split(content, "\n")

    # Update the current line
    socket = update_line_content(socket, line_number, first_line)

    # Insert new lines after the current one
    socket = insert_new_lines(socket, line_number, new_lines)

    # Renumber all lines
    socket = renumber_lines(socket)

    {:noreply, socket}
  else
    # Simple single-line update
    {:noreply, update_line_content(socket, line_number, content)}
  end
end


# Helper functions


  def create_data_grid(content) do
    String.split(content, "\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {line, index} ->
      %DataGridSchema.Line{line_number: index, content: line, note: ""}
    end)
  end

  defp update_line_content(socket, line_number, content) do
    Logger.info("trying to update_line_content at line #{line_number} with content #{content}")
    update(socket, :lines, fn lines ->
      Enum.map(lines, fn line ->
        if line.line_number == line_number do
          %{line | content: content}
        else
          line
        end
      end)
    end)
  end


  defp insert_new_lines(socket, after_line_number, contents) do
    update(socket, :lines, fn lines ->
      {before_lines, after_lines} = Enum.split_while(lines, &(&1.id != after_line_number))
      [current_line | rest] = after_lines

      new_lines = Enum.map(contents, fn content ->
        ## Add a function to DataGridSchema to generate
        %DataGridSchema.Line{
          id: DataGridSchema.generate_line_number(),
          content: content,
          note: ""
        }
      end)

      before_lines ++ [current_line] ++ new_lines ++ rest
    end)
  end

  defp renumber_lines(socket) do
    update(socket, :lines, fn lines ->
      lines
      |> Enum.with_index(1)
      |> Enum.map(fn {line, idx} -> %{line | number: idx} end)
    end)
  end

  end

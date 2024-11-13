defmodule AnnotatorWeb.OldTextAnnotator do
  use Phoenix.LiveView
  alias Annotator.DataGridSchema
  alias Phoenix.LiveView.JS
  alias Phoenix.HTML
  import AnnotatorWeb.AnnotatorComponents
  require Logger

  def mount(_params, _session, socket) do
    Logger.info("TextAnnotator liveview mount -- all the assigns get reset when this happens")
    {:ok, assign(socket,
      lines: [%DataGridSchema.Line{line_number: 0, content: "", note: ""},
        %DataGridSchema.Line{id: "two", line_number: 1, content: "Here's two content and I need to make it longer so it'll wrap; hey, let's put that in the seed content. [Wait I need some special \\ characters /]", note: "Here's a note on row number 1"},
        %DataGridSchema.Line{id: "three", line_number: 2, content: "Third content", note: "Third note"}
        ],
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
        end
      end}
          >
      <:col :let={line} name="line-num" label="#" editable={false}><%= line.line_number %></:col>
      <:col :let={line} name="content" label="Content" editable={true}><pre class="whitespace-pre-wrap"><code><%= line.content %></code></pre></:col>
      <:col :let={line} name="note" label="Note" editable={true}><div><%= HTML.raw Earmark.as_html!(line.note, breaks: true) %></div></:col>
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

  # def handle_event("click_focus", %{"row_index" => row_index, "col_index" => col_index}, socket) do
  #   Logger.info("click_focus handler. {row_index, col_index}: {#{row_index}, #{col_index}}")
  #   {:noreply, assign(socket, focused_cell: {row_index, col_index})}
  # end

  def handle_event("prompt_save_changes", _params, socket) do
    Logger.info("TODO: add a prompt to save or abandon edits to the cell before blurring")
    {:noreply, socket}
  end


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
    Logger.info("update_cell handler called. Check row_index: #{row_index}. Check new_value: #{new_value}")
    if is_binary(row_index), do: Logger.info("row_index is a binary coming into update_cell handler"); row_num = String.to_integer(row_index)

    lines = socket.assigns.lines #|> IO.inspect()

    # Get the column name based on index
    field_name = case col_index do
      "1" -> "content"
      "2" -> "note"
      _ -> nil
    end

    # Convert field_name to atom if it's a string
    field_name = if is_binary(field_name), do: String.to_existing_atom(field_name), else: field_name

    line_to_edit = Enum.find(lines, fn line ->
        line.line_number == row_num end) # row_num and line_number are both integers

    edited_line = Map.put(line_to_edit, field_name, new_value)
    Logger.info("edited_line before any splitting: #{inspect edited_line}")

    if field_name == :content do
      Logger.info(" ")
      Logger.info("field name is content so check for added lines")
      {before_lines, rest} = Enum.split_while(socket.assigns.lines, &(&1.line_number != row_num))
      # Logger.info("before_lines: #{inspect before_lines}")

      {edited_lines, offset}  = process_edited_line(edited_line, row_num)
      Logger.info("edited_lines, offset: #{inspect edited_lines}, #{offset}")

      updated_lines = before_lines ++ edited_lines ++ renumber_lines(rest, offset)
      {:noreply, assign(socket, lines: updated_lines, editing: nil)}

    else
      updated_lines = Enum.map(lines, fn line ->
        if line.line_number == row_num do
          Map.put(line, field_name, new_value)
        else
          line
        end
      end)
      {:noreply, assign(socket, lines: updated_lines, editing: nil)}
    end
  end

  def handle_event("delete_line", _params, socket) do
    row_num = elem(socket.assigns.editing, 0)
    {before_lines, rest} = Enum.split_while(socket.assigns.lines, &(&1.line_number != row_num))
    after_lines = renumber_lines(rest, -1)
    updated_lines = before_lines ++ after_lines
    {:noreply, assign(socket, lines: updated_lines, editing: nil)}
  end


  # Helper functions
  defp process_edited_line(line, row_num) do
    # row_num = String.to_integer(row_index)
    Logger.info("Row number of the edited line to be processed: #{row_num}")
    content_list = String.split(line.content, "\n")
    num_lines = Enum.count(content_list)
    if num_lines > 1 do
      first_line = %DataGridSchema.Line{line_number: row_num, content: Enum.at(content_list, 0), note: line.note}
      added_lines = content_list |> Enum.drop(1)
        |> Stream.with_index(row_num + 1)  # Start index at row_num + 1
        |> Enum.map(fn {content, i} ->
          # Logger.info("renumbering new line at #{i}")
          %DataGridSchema.Line{
            line_number: i,
            content: content,
            note: ""
          }
          end)
      {[first_line | added_lines], num_lines - 1}
    else
      {[line], 0}
    end
  end

  defp renumber_lines(after_split, offset) do
    result = after_split
    |> Enum.drop(1)
    |> Enum.map(fn line -> %{line | line_number: line.line_number + offset} end)
    # Logger.info("inspect result: #{inspect result}")
    result
  end

  def create_data_grid(content) do
    String.split(content, "\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {line, index} ->
      %DataGridSchema.Line{line_number: index, content: line, note: ""}
    end)
  end

end
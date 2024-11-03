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
        editing: nil  # nil or {line_number, :content|:note}
      )}
    end

    def render(assigns) do

      ~H"""
      <.anno_grid id="this-annotated-content" rows={@lines}
      row_click={fn row, col ->
      if col[:name] in ["content", "note"] do
        JS.push("start_edit", value: %{row_id: row.id, column: col[:name]})
      end
    end}>
        <:col :let={line} name="line-num" label="#"><%= line.line_number %></:col>
        <:col :let={line} name="content" label="Content"><%= line.content %></:col>
        <:col :let={line} name="note" label="Note"><%= line.note %></:col>
      </.anno_grid>

        <div class="data-grid">
        <div
          role="grid"
          aria-label="Code content and notes"
          phx-window-keyup="handle_keyup"
          phx-value-focused_row={@focused_cell |> elem(0)}
          class="grid-container"
          tabindex="0"
        >
          <div role="row" class="header">
            <div role="columnheader" class="line-number">#</div>
            <div role="columnheader" class="content">Content</div>
            <div role="columnheader" class="notes">Notes</div>
          </div>
          <%= for line <- @lines do %>
            <div role="row" class="grid-row">
              <div role="gridcell"
              class="line-number"
              tabindex="-1"
              id={if(@focused_cell == {line.line_number, 1}, do: "focused")}
              >
                <%= line.line_number %>
                <p>BTW the value of the editing attribute is <%= inspect @editing %>,</p>
                <p>The focused cell is <%= inspect @focused_cell %>,</p>
                <p>And line.line_number is <%= inspect line.line_number %></p>
              </div>
              <%= if @editing == {line.line_number, :content} do %>
                <div
                  role="gridcell"
                  tabindex="-1"
                  phx-value-line_number={line.line_number}
                  phx-value-field="content"
                  id={if(@focused_cell == {line.line_number, 1}, do: "focused")}
                  class={[
                    "content",
                    if(@focused_cell == {line.line_number, 1}, do: "focused")
                  ]}
                >
                  <form phx-submit="update_content" phx-value-line_number={line.line_number}>
                    <input type="text"
                          name="content"
                          value={line.content}
                          phx-debounce="200"
                          autofocus />
                  </form>
                </div>
              <% else %>
                <div
                    role="gridcell"
                    tabindex="-1"
                    phx-click="start_edit"
                    phx-value-line_number={line.line_number}
                    phx-value-field="content"
                    id={if(@focused_cell == {line.line_number, 1}, do: "focused")}
                    class={[
                      "content",
                      if(@focused_cell == {line.line_number, 1}, do: "focused")
                    ]}
                  >
                  <pre><code><%= line.content %></code></pre>
                </div>
              <% end %>
              <div role="gridcell"
                tabindex="-1"
                phx-click="start_edit"
                phx-value-line_number={line.line_number}
                phx-value-field="note"
                class="notes">
                <%= if @editing == {line.line_number, :note} do %>
                  <form phx-submit="update_note">
                    <input type="text"
                          name="note"
                          value={line.note}
                          phx-value-line_number={line.line_number}
                          phx-debounce="200"
                          />
                  </form>
                <% else %>
                  <%= line.note %>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
      """
    end

    ## Helpers
0

    def handle_event("start_edit",  %{"row_id" => row_id, "column" => column}, socket) do
      Logger.info("start_edit handler. row: #{row_id}")
      {:noreply, socket}
    end

    def create_data_grid(content) do
      String.split(content, "\n")
      |> Enum.with_index(1)
      |> Enum.map(fn {line, index} ->
        %DataGridSchema.Line{line_number: index, content: line, note: ""}
      end)
    end

    ## Event handlers

    def handle_event("handle_keyup", %{"key" => "Enter"}, socket) do
      Logger.info("checking focused_cell: #{inspect socket.assigns.focused_cell}")
      {row, col} = socket.assigns.focused_cell
      Logger.info("editing: #{inspect socket.assigns.editing}")
      if col == 1 do
        Logger.info("detected the Enter key on cell #{inspect {row,col}}")
        the_line = Enum.find(socket.assigns.lines, fn line -> line.line_number == row end)
        Logger.info("cell #{inspect {row,col}} corresponds to the line #{inspect the_line}")
        # Logger.info("Check if phx- values on element get passed up to phx-window-keyup: line_number= #{line_number}")
            with nil <- socket.assigns.editing do
              # Enter edit mode
              Logger.info("change assigns to try to enter edit mode with editing #{the_line.line_number}, :content")
              {:noreply, assign(socket, editing: {the_line.line_number, :content})}
            else
              # If we were already in edit mode don't capture; key events
              _ -> {:noreply, socket}
            end
      else
        Logger.info("Enter on a non-editable cell; disregarding")
        {:noreply, socket}
      end

    end

    def handle_event("handle_keyup", %{"key" => "ArrowUp"}, socket) do
      {row, col} = socket.assigns.focused_cell
      Logger.info("detected ArrowUp key on cell #{inspect {row,col}}")
      if row > 0 do
        Logger.info("moving up")
        {:noreply, assign(socket, focused_cell: {row - 1, col})}
      else
        Logger.info("already at row 0")
        {:noreply, socket}
      end
    end

    def handle_event("handle_keyup", %{"key" => "ArrowDown"}, socket) do
      {row, col} = socket.assigns.focused_cell
      Logger.info("detected ArrowDown key on cell #{inspect {row,col}}")
      if row < length(socket.assigns.lines) - 1 do
        Logger.info("moving down")
        {:noreply, assign(socket, focused_cell: {row + 1, col})}
      else
        Logger.info("already at last row")
        {:noreply, socket}
      end
    end

    def handle_event("handle_keyup", %{"key" => "ArrowLeft"}, socket) do
      {row, col} = socket.assigns.focused_cell
      Logger.info("detected ArrowLeft key on cell #{inspect {row,col}}")
      if col > 1 do
        Logger.info("moving left")
        focus_cell({row, col - 1})
        {:noreply, assign(socket, focused_cell: {row, col - 1})}
      else
        Logger.info("already at col 1")
        {:noreply, socket}
      end
    end

    def handle_event("handle_keyup", %{"key" => "ArrowRight"}, socket) do
      {row, col} = socket.assigns.focused_cell
      Logger.info("detected ArrowRight key on cell #{inspect {row,col}}")
      if col < 2 do
        Logger.info("moving right")
        {:noreply, assign(socket, focused_cell: {row, col + 1})}
      else
        Logger.info("already at col 2")
        {:noreply, socket}
      end
    end

    def handle_event("handle_keyup", _, socket) do
      {:noreply, socket}

    end

    # ... other event handlers for editing ...
    # When user clicks or keypresses to edit
def handle_event("start_edit", %{"line_number" => line_number, "field" => field}, socket) do
  Logger.info("start_edit handler has been invoked. Do I want to move this listener to the whole grid?")
  Logger.info("trying to set editing to #{inspect {line_number, String.to_atom(field)}}")
  assign(socket, editing: {String.to_integer(line_number), String.to_atom(field)})
  JS.focus(to: "")
  {:noreply, assign(socket, editing: {String.to_integer(line_number), String.to_atom(field)})}
end

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

# Handle note updates
  def handle_event("update_note", %{"line_number" => line_number, "note" => note}, socket) do
    {:noreply, update_line_note(socket, line_number, note)}
  end

# Helper functions

  defp focus_cell(cell) do
    Logger.info("in focus_cell")
    {row, col} = cell

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

  defp update_line_note(socket, line_number, note) do
    update(socket, :lines, fn lines ->
      Enum.map(lines, fn line ->
        if line.line_number == line_number do
          %{line | note: note}
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

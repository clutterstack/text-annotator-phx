defmodule AnnotatorWeb.TextAnnotator do
  use Phoenix.LiveView
  alias Annotator.DataGridSchema

  require Logger

    def mount(_params, _session, socket) do
      {:ok, assign(socket,
        lines: [%DataGridSchema{line_number: 1, content: "", note: ""}],
        focused_cell: {0, 1},  # {row, col}
        edit_mode: false
      )}
    end


    def render(assigns) do
      ~H"""
      <div class="code-grid">
        <div
          role="grid"
          aria-label="Code content and notes"
          phx-window-keydown="handle_keydown"
          tabindex="0"
          class="grid-container"
        >
          <div role="row" class="header">
            <div role="columnheader" class="line-number">#</div>
            <div role="columnheader" class="content">Content</div>
            <div role="columnheader" class="notes">Notes</div>
          </div>

          <%= for {line, index} <- Enum.with_index(@lines) do %>
            <div role="row" class="grid-row">
              <div role="gridcell" class="line-number">
                <%= line.line_number %>
              </div>
              <div
                role="gridcell"
                phx-click="focus_cell"
                phx-value-row={index}
                phx-value-col="1"
                tabindex={if @focused_cell == {index, 1}, do: "0", else: "-1"}
                class={[
                  "content",
                  @focused_cell == {index, 1} && "focused"
                ]}
              >
                <%= if @edit_mode && @focused_cell == {index, 1} do %>
                  <form phx-change="update_content" phx-submit="finish_edit">
                    <input type="text" name="content" value={line.content} autofocus />
                  </form>
                <% else %>
                  <pre><code><%= line.content %></code></pre>
                <% end %>
              </div>
              <div
                role="gridcell"
                phx-click="focus_cell"
                phx-value-row={index}
                phx-value-col="2"
                tabindex={if @focused_cell == {index, 2}, do: "0", else: "-1"}
                class={[
                  "notes",
                  @focused_cell == {index, 2} && "focused"
                ]}
              >
                <%= if @edit_mode && @focused_cell == {index, 2} do %>
                  <form phx-change="update_note" phx-submit="finish_edit">
                    <input type="text" name="note" value={line.note} autofocus />
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

    def create_data_grid(content) do
      String.split(content, "\n")
      |> Enum.with_index(1)
      |> Enum.map(fn {line, index} ->
        %DataGridSchema{line_number: index, content: line, note: ""}
      end)

      # %CodeGridSchema{lines: lines}
    end

    ## Event handlers
    def handle_event("handle_keydown", %{"key" => key}, socket) do
      {row, col} = socket.assigns.focused_cell

      new_focus = case key do
        "ArrowUp" when row > 0 -> {row - 1, col}
        "ArrowDown" when row < length(socket.assigns.lines) - 1 -> {row + 1, col}
        "ArrowLeft" when col > 1 -> {row, col - 1}
        "ArrowRight" when col < 2 -> {row, col + 1}
        "Enter" ->
          # Toggle edit mode
          socket = update(socket, :edit_mode, &(!&1))
          {row, col}
        _ -> {row, col}
      end

      {:noreply, assign(socket, focused_cell: new_focus)}
    end

    # ... other event handlers for editing ...
  end

defmodule AnnotatorWeb.AnnotatorComponents do
  use Phoenix.Component
  require Logger

  # use AnnotatorWeb, :html

  attr :id, :string, default: "the_grid" # needed for phx-update on the data-grid element
  attr :rows, :map, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"
  # Here's one that works: row_click={fn %Annotator.DataGridSchema.Line{:line_number => line_number} -> rowclick(line_number) end
  # This attr gets used like `phx-click={@row_click && @row_click.(row)}`  which tells us approximately "if the row_click attr exists, pass the value of `row` to it and pass that to phx-click." Sort of.

  attr :row_item, :any,
  default: &Function.identity/1,
  doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
    attr :name, :string
  end

  def anno_grid(assigns) do
    # This is a function that creates an assign for every row, I think. Something
    # to do with LiveStream and dynamic IDs.
    assigns =
      with %{lines: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end
    ~H"""
    <div class="data-grid"
      role="grid"
      tabindex="0"
      id={@id}
      phx-hook="GridNav"
      aria-label="Code content and notes"
      phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
      >
      <div role="rowgroup">
        <div role="row" class="header">
          <div :for={col <- @col} role="columnheader" aria-sort="none"
 class="line-number"><%= col[:label] %></div>
        </div>
      </div>
      <div role="rowgroup">
        <div :for={row <- @rows} role="row" id={@row_id && @row_id.(row)} class="group hover:bg-zinc-100 heyyou">
          <div
            :for={{col, i} <- Enum.with_index(@col)}
            tabindex="-1"
            phx-click={@row_click && @row_click.(row, col)}
            class={["grid-cell", "#{col[:name]}", @row_click && "hover:cursor-pointer"]}
          >
            <div>
              <span class={[i == 0 && "text-zinc-400"]}>
                <%= render_slot(col, @row_item.(row)) %>
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end


  def anno_grid_cell(assigns) do
    ~H"""
    <span> Hi there </span>
    """
    # <%= if @editing == {line.line_number, :content} do %>
    #             <div
    #               role="gridcell"
    #               tabindex="-1"
    #               phx-value-line_number={line.line_number}
    #               phx-value-field="content"
    #               id={if(@focused_cell == {line.line_number, 1}, do: "focused")}
    #               class={[
    #                 "content",
    #                 if(@focused_cell == {line.line_number, 1}, do: "focused")
    #               ]}
    #             >
    #               <form phx-submit="update_content" phx-value-line_number={line.line_number}>
    #                 <input type="text"
    #                       name="content"
    #                       value={line.content}
    #                       phx-debounce="200"
    #                       autofocus />
    #               </form>
    #             </div>
    #           <% else %>
    #             <div
    #                 role="gridcell"
    #                 tabindex="-1"
    #                 phx-click="start_edit"
    #                 phx-value-line_number={line.line_number}
    #                 phx-value-field="content"
    #                 id={if(@focused_cell == {line.line_number, 1}, do: "focused")}
    #                 class={[
    #                   "content",
    #                   if(@focused_cell == {line.line_number, 1}, do: "focused")
    #                 ]}
    #               >
    #               <pre><code><%= line.content %></code></pre>
    #             </div>
    #           <% end %>
    #
  end

  attr :chunk, :map, required: true

  def text_with_highlights(assigns) do
    Logger.info("text_with_highlights is being called; chunk is #{inspect(assigns.chunk)}")
    high_start = assigns.chunk.highlight_start
    high_end = assigns.chunk.highlight_end

    {start_pos, end_pos} = if high_start <= high_end do
      {high_start, high_end}
    else
      {high_end, high_start}
    end
    assigns = assign(assigns, start_pos: start_pos, end_pos: end_pos)

    ~H"""
    <%= String.slice(@chunk.text, 0, @start_pos) %>
    <span class="bg-yellow-200">
      <%= String.slice(@chunk.text, @start_pos, @end_pos - @start_pos) %>
    </span>
    <%= String.slice(@chunk.text, @end_pos..-1//1) %>
    """
  end
end

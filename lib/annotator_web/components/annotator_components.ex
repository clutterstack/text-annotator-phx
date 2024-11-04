defmodule AnnotatorWeb.AnnotatorComponents do
  use Phoenix.Component
  require Logger

  # use AnnotatorWeb, :html
  attr :editing, :any, default: nil, doc: "tuple of {row_id, column} currently being edited"
  attr :focused_cell, :any, default: nil, doc: "tuple of {row_index, col_index} currently focused"

  attr :id, :string, default: "the_grid" # needed for phx-update on the data-grid element
  attr :rows, :map, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"
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
      <div role="rowgroup" class="grid grid-cols-subgrid col-span-3">
        <div role="row" class="header grid grid-cols-subgrid col-span-3">
          <div :for={col <- @col} role="columnheader" aria-sort="none"
            class={["#{col[:name]}"]}><%= col[:label] %></div>
        </div>
      </div>
      <div role="rowgroup" class="grid grid-cols-subgrid col-span-3">
        <div :for={{row, row_index} <- Enum.with_index(@rows)}
          role="row"
          id={@row_id && @row_id.(row)}
          class="group hover:bg-zinc-100 heyyou grid grid-cols-subgrid col-span-3">
          <div
            :for={{col, col_index} <- Enum.with_index(@col)}
            tabindex="-1"
            role="gridcell"
            data-focused={@focused_cell == {row_index, col_index}}
            class={["grid-cell", "#{col[:name]}", @row_click && "hover:cursor-pointer",
              @focused_cell == {row_index, col_index} && "ring-2 ring-blue-500"]}
          >
            <%= if @editing == {row_index, col_index} do %>
              <div class="w-full">
                <form phx-submit="update_cell">
                  <input type="hidden" name="row_id" value={row.id} />
                  <input type="hidden" name="column" value={col[:name]} />
                  <input
                    type="text"
                    name="value"
                    value={Map.get(row, String.to_existing_atom(col[:name]))}
                    class="w-full p-1 border rounded"
                    phx-blur="cancel_edit"
                    phx-debounce="200"
                    autofocus
                  />
                </form>
              </div>
            <% else %>
              <div
                phx-click={@row_click && @row_click.(row_index, col, col_index)}
              >
                <span class={[col_index == 0 && "text-zinc-400"]}>
                  <%= render_slot(col, @row_item.(row)) %>
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
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

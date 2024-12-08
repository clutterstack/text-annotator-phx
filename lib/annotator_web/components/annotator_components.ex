defmodule AnnotatorWeb.AnnotatorComponents do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  require Logger
  attr :mode, :string, default: "read-only"
  attr :editing, :any, default: nil
  attr :selection, :any, default: nil
  attr :active_chunk, :any, default: nil


  attr :lines, :list, required: true
  attr :chunks, :list, required: true

  slot :col, required: true do
    attr :label, :string
    attr :name, :string
    attr :editable, :boolean
    attr :deletable, :boolean
  end

  def anno_grid(assigns) do
    chunk_groups = group_lines_by_chunks(assigns.lines, assigns.chunks)
    assigns = assign(assigns, :chunk_groups, chunk_groups)
    ~H"""
    <div class="w-full grid grid-cols-[min-content_min-content_1fr_1fr] items-start rounded-lg border"
        role="grid"
        tabindex="0"
        id="annotated-content"
        phx-hook="GridNav"
        data-mode={@mode}
        aria-multiselectable="true">
      <div role="rowgroup" class="grid grid-cols-subgrid col-span-4">
        <div role="row" class="grid grid-cols-subgrid col-span-4 border-b bg-zinc-50">
          <div :for={col <- @col}
                role="columnheader"
                class="p-1 text-sm font-medium text-zinc-500">
            <%= col[:label] %>
          </div>
        </div>
      </div>

      <div role="rowgroup" class="grid grid-cols-subgrid col-span-4">
        <%= for {group, row_index} <- Enum.with_index(@chunk_groups) do %>
          <% {chunk, lines} = group %>
          <% rowspanclass = "row-span-" <> to_string(Enum.count(lines)) %>
          <div role="row"
                class={[
                  "grid grid-cols-subgrid col-span-4",
                  "hover:bg-zinc-50",
                  row_index != length(@chunk_groups) - 1 && "border-b",
                  # Add selected state styling
                  is_selected?(lines, @selection) && "bg-blue-50"
                ]}
                aria-selected={is_selected?(lines, @selection)}>
            <%= for {col, col_index} <- Enum.with_index(@col) do %>
              <div role="gridcell"
                tabindex="-1"
                id={"cell" <> to_string(row_index) <> to_string(col_index)}
                data-col={col[:name]}
                data-col-index={col_index}
                data-row-index={row_index}
                data-first-line={if(lines != [], do: List.first(lines).line_number)}
                data-last-line={if(lines != [], do: List.last(lines).line_number)}
                data-chunk-id={if(chunk, do: chunk.id)}
                data-selectable={col[:name] == "line-num"}
                data-deletable={col[:deletable]}
                aria-label={get_aria_label(col, lines, chunk)}
                class={[
                  rowspanclass,
                  "p-1 min-h-[3rem] z-30 focus:bg-fuchsia-600",
                  col_index != length(@col) - 1 && "border-r",
                  col[:editable] && @mode !== "read-only" && "hover:cursor-pointer hover:bg-zinc-100/50 editable",
                  col[:name] in ["line-num", "content"] && "grid grid-rows-subgrid"
                ]}
                >
                <%= if @editing == {to_string(row_index), to_string(col_index)} do %>
                  <.editor
                    group={{chunk, lines}}
                    col={col}
                    row_index={row_index}
                    col_index={col_index}
                    edit_text={get_edit_text(col[:name], {chunk, lines}, lines)}
                  />
                <% else %>
                  <.cell_content
                    col={col}
                    row_index={to_string(row_index)}
                    col_index={to_string(col_index)}
                    chunk={chunk}
                    lines={lines}
                    col_name={col[:name]}
                  />
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

      <div class="mt-4 text-sm text-gray-600" role="complementary" aria-label="Keyboard shortcuts">
        <p>Press <kbd>Space</kbd> to start selection</p>
        <p>Use <kbd>↑</kbd> <kbd>↓</kbd> to navigate, <kbd>Shift + ↑/↓</kbd> to select multiple lines</p>
        <p>Press <kbd>n</kbd> to add a note to selected lines</p>
        <p>Press <kbd>Esc</kbd> to cancel selection</p>
      </div>
    """
  end


  defp is_selected?(lines, selection) when not is_nil(selection) do
    first_line = List.first(lines)
    last_line = List.last(lines)

    first_line && last_line &&
      first_line.line_number >= min(selection.start_line, selection.end_line) &&
      last_line.line_number <= max(selection.start_line, selection.end_line)
  end
  defp is_selected?(_, _), do: false

  defp get_aria_label(col, lines, chunk) do
    case col[:name] do
      "line-num" ->
        if length(lines) == 1 do
          "Line #{List.first(lines).line_number}"
        else
          "Lines #{List.first(lines).line_number} through #{List.last(lines).line_number}"
        end
      "line-span" ->
        if lines == [] do
          "0"
        else
          case length(lines) do
            1 ->
              List.first(lines).line_number
            _ ->
              "#{List.first(lines).line_number}-#{List.last(lines).line_number}"
          end
        end
      "content" -> "Content: #{Enum.map_join(lines, " ", & &1.content)}"
      "note" -> "Note: #{chunk && chunk.note || "No note"}"
    end
  end

  defp get_edit_text("content", _group, lines) do
    Enum.map_join(lines, "\n", & &1.content)
  end
  defp get_edit_text("note", {chunk, _lines}, _) do
    chunk && chunk.note || ""
  end
  defp get_edit_text(_, _, _), do: ""

  # Group lines into chunks, including uncategorized lines in their own group
  defp group_lines_by_chunks(lines, chunks) do
    # Create a map of line_id to chunk
    chunk_map = chunks
    |> Enum.reduce(%{}, fn chunk, acc ->
      line_ids = chunk.chunk_lines |> Enum.map(& &1.line_id)
      Enum.reduce(line_ids, acc, fn line_id, inner_acc ->
        Map.put(inner_acc, line_id, chunk)
      end)
    end)
    # Group lines into chunks or create standalone groups
    lines
    |> Enum.chunk_while(
      {nil, []},  # Initial accumulator: {current_chunk, current_lines}
      fn line, {current_chunk, current_lines} = acc ->
        line_chunk = Map.get(chunk_map, line.id)
        cond do
          # First line or continuing same chunk
          current_chunk == nil or line_chunk == current_chunk ->
            {:cont, {line_chunk, [line | current_lines]}}
          # Found a new chunk, emit current group and start new one
          true ->
            {:cont, {current_chunk, Enum.reverse(current_lines)}, {line_chunk, [line]}}
        end
      end,
      fn
        {nil, []} -> {:cont, []}
        {chunk, lines} -> {:cont, {chunk, Enum.reverse(lines)}, {nil, []}}
      end
    )
    |> Enum.reject(fn {_chunk, lines} -> lines == [] end)  # Remove empty groups
    |> Enum.sort_by(fn {_chunk, lines} ->
      case lines do
        [first | _] -> first.line_number
        [] -> 0
      end
    end)
  end

  attr :col, :any, required: true
  attr :chunk, :any
  attr :lines, :list
  attr :selection, :any, default: nil
  attr :row_index, :string
  attr :col_index, :string
  def cell_content(assigns) do
    ~H"""
    <%= case @col[:name] do %>
      <% "line-num" -> %>
        <%= for line <- @lines do %>
          <div class="line-number py-1 hover:bg-zinc-100/50 focus:bg-fuchsia-600 rounded cursor-pointer z-40 min-h-4 self-start"
              role="button"
              tabindex="-1"
              data-line-number={line.line_number}
              data-selectable="true"
              aria-selected={is_line_selected?(line, @selection)}>
              <pre><code><%= line.line_number %></code></pre>
          </div>
        <% end %>
      <% "content" -> %>
        <%= for line <- @lines do %>
          <div class="py-1 hover:bg-zinc-100/50 self-start"
              role="presentation"
              phx-click={JS.focus(to: "#cell" <> @row_index <> @col_index)}
              phx-value-row={@row_index}
              phx-value-col={@col_index}
              tabindex="0" >
              <pre class="whitespace-pre-wrap"><code><%= line.content %></code></pre>
          </div>
        <% end %>
      <% "line-span" -> %>
      <div>
          <%= if @lines == [] do %>
            <%= "0" %>
          <% else %>
            <%= case length(@lines) do %>
              <% 1 -> %>
                <%= List.first(@lines).line_number %>
              <% _ -> %>
                <%= "#{List.first(@lines).line_number}-#{List.last(@lines).line_number}" %>
            <% end %>
          <% end %>
          </div>
      <% "note" -> %>
          <%= @chunk && @chunk.note || "No note" %>
      <% _ -> %>
        <%= if @col do %>
          <%= inspect(@col) %>
        <% else %>
          Even col isn't there
        <% end %>
    <% end %>
    """
  end

  defp is_line_selected?(line, selection) when not is_nil(selection) do
    line.line_number >= min(selection.start_line, selection.end_line) &&
    line.line_number <= max(selection.start_line, selection.end_line)
  end
  defp is_line_selected?(_, _), do: false

  attr :row_index, :integer, required: true
  attr :col_index, :integer, required: true
  # attr :group, :any, required: true
  # attr :col, :map, required: true
  attr :edit_text, :string, required: true
  def editor(assigns) do
    ~H"""
    <form phx-submit="update_cell">
      <input type="hidden" name="row_index" value={@row_index}/>
      <input type="hidden" name="col_index" value={@col_index}/>
      <textarea
        class="block w-full h-full min-h-[6rem] p-2 border rounded"
        name="value"
        id={"editor-#{@row_index}-#{@col_index}"}
        phx-hook="CtrlEnter"
        data-row-index={@row_index}
        phx-debounce="200"
        autofocus
      ><%= @edit_text %></textarea>
    </form>
    """
  end
end

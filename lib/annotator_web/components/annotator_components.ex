defmodule AnnotatorWeb.AnnotatorComponents do
  use Phoenix.Component
  require Logger

  attr :editing, :any, default: nil
  attr :edit_text, :string, default: ""
  attr :focused_cell, :any, default: nil
  attr :selection, :any, default: nil
  attr :active_chunk, :any, default: nil

  attr :id, :string, required: true
  attr :lines, :list, required: true
  attr :chunks, :list, required: true
  attr :row_click, :any, default: nil

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
    <div class="w-full"
         role="grid"
         tabindex="0"
         id={@id}
         phx-hook="GridNav"
         aria-multiselectable="true">
      <div class="border rounded-lg overflow-hidden bg-white">
        <div role="rowgroup">
          <div role="row" class="grid grid-cols-[80px_1fr_1fr] border-b bg-zinc-50">
            <div :for={col <- @col}
                 role="columnheader"
                 class="p-3 text-sm font-medium text-zinc-500">
              <%= col[:label] %>
            </div>
          </div>
        </div>

        <div role="rowgroup">
          <%= for {group, row_index} <- Enum.with_index(@chunk_groups) do %>
            <% {chunk, lines} = group %>
            <div role="row"
                 class={[
                   "grid grid-cols-[80px_1fr_1fr]",
                   "group hover:bg-zinc-50",
                   row_index != length(@chunk_groups) - 1 && "border-b",
                   # Add selected state styling
                   is_selected?(lines, @selection) && "bg-blue-50"
                 ]}
                 aria-selected={is_selected?(lines, @selection)}>
              <%= for {col, col_index} <- Enum.with_index(@col) do %>
                <div role="gridcell"
                  tabindex={if(col_index == 0, do: "0", else: "-1")}
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
                    "p-3 min-h-[3rem]",
                    col_index != length(@col) - 1 && "border-r",
                    "relative group",
                    col[:editable] && "hover:cursor-pointer hover:bg-zinc-100/50 editable"
                  ]}
                  phx-click={@row_click && @row_click.(row_index, col_index)}
                  phx-keydown={if(col[:name] == "line-num", do: "handle_selection")}
                  >
                  <%= if @editing == {to_string(row_index), to_string(col_index)} do %>
                    <.editor
                      group={{chunk, lines}}
                      col={col}
                      row_index={row_index}
                      col_index={col_index}
                      edit_text={get_edit_text(@edit_text, col[:name], {chunk, lines}, lines)}
                    />
                  <% else %>
                    <.cell_content
                      col={col}
                      chunk={chunk}
                      lines={lines}
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
      "content" -> "Content: #{Enum.map_join(lines, " ", & &1.content)}"
      "note" -> "Note: #{chunk && chunk.note || "No note"}"
    end
  end

  defp get_edit_text(edit_text, "content", _group, lines) when edit_text == "" do
    Enum.map_join(lines, "\n", & &1.content)
  end
  defp get_edit_text(edit_text, "content", _group, _lines) do
    edit_text
  end
  defp get_edit_text(_edit_text, "note", {chunk, _lines}, _) do
    chunk && chunk.note || ""
  end
  defp get_edit_text(_, _, _, _), do: ""

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
    def cell_content(assigns) do
      ~H"""
      <%= case @col[:name] do %>
        <% "line-num" -> %>
          <div class="flex flex-col">
            <%= for line <- @lines do %>
              <div class="py-1 px-2 hover:bg-zinc-100 rounded cursor-pointer"
                  role="button"
                  tabindex="0"
                  data-line-number={line.line_number}
                  data-selectable="true"
                  phx-click="toggle_line_selection"
                  phx-value-line={line.line_number}
                  aria-selected={is_line_selected?(line, @selection)}
                  class={[
                    is_line_selected?(line, @selection) && "bg-blue-100 hover:bg-blue-200"
                  ]}>
                <%= line.line_number %>
              </div>
            <% end %>
          </div>
        <% "line-span" -> %>
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

        <% "content" -> %>
          <pre class="whitespace-pre-wrap"><code><%= Enum.map_join(@lines, "\n", & &1.content) %></code></pre>

        <% "note" -> %>
          <div class={if(@chunk, do: "text-gray-900", else: "text-gray-400")}>
            <%= @chunk && @chunk.note || "No note" %>
          </div>

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

defmodule AnnotatorWeb.AnnotatorComponents do
  use Phoenix.Component
  require Logger

  attr :editing, :any, default: nil
  attr :edit_text, :string, default: ""
  attr :focused_cell, :any, default: nil
  attr :selection, :any, default: nil
  attr :active_chunk, :any, default: nil

  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :chunks, :list, required: true
  attr :row_click, :any, default: nil

  slot :col, required: true do
    attr :label, :string
    attr :name, :string
    attr :editable, :boolean
    attr :deletable, :boolean
  end


  def anno_grid(assigns) do
    chunk_groups = group_lines_by_chunks(assigns.rows, assigns.chunks)

    Logger.info("Grouped #{length(assigns.rows)} lines into #{length(chunk_groups)} groups")
    for {chunk, lines} <- chunk_groups do
      if chunk do
        Logger.info("Chunk #{chunk.id} contains lines #{inspect(Enum.map(lines, & &1.line_number))}")
      else
        Logger.info("Ungrouped lines: #{inspect(Enum.map(lines, & &1.line_number))}")
      end
    end

    assigns = assign(assigns, :chunk_groups, chunk_groups)

    ~H"""
    <div class="w-full" role="grid" tabindex="0" id={@id} phx-hook="GridNav">
      <div class="border rounded-lg overflow-hidden bg-white">
        <div role="rowgroup">
          <div role="row" class="grid grid-cols-[80px_1fr_1fr] border-b bg-zinc-50">
            <div :for={col <- @col} role="columnheader" class="p-3 text-sm font-medium text-zinc-500">
              <%= col[:label] %>
            </div>
          </div>
        </div>

        <div role="rowgroup">
          <%= for {group, group_idx} <- Enum.with_index(@chunk_groups) do %>
            <% {chunk, lines} = group %>
            <div role="row"
              class={[
                "grid grid-cols-[80px_1fr_1fr]",
                "group hover:bg-zinc-50",
                group_idx != length(@chunk_groups) - 1 && "border-b"
              ]}>
              <div
                :for={{col, col_index} <- Enum.with_index(@col)}
                role="gridcell"
                tabindex="-1"
                data-col={col[:name]}
                data-first-line={if(lines != [], do: List.first(lines).line_number)}
                data-last-line={if(lines != [], do: List.last(lines).line_number)}
                data-chunk-id={if(chunk, do: chunk.id)}
                data-selectable={col[:name] == "line-num"}
                data-deletable={col[:deletable]}
                class={[
                  "p-3 min-h-[3rem]",
                  col_index != length(@col) - 1 && "border-r",
                  "relative group",
                  col[:editable] && "hover:cursor-pointer hover:bg-zinc-100/50"
                ]}
                phx-click={@row_click && @row_click.(group_idx, col, col_index)}
              >
                <%= cond do %>
                  <% @editing == {to_string(group_idx), to_string(col_index)} -> %>
                    <.editor
                      group={group}
                      col={col}
                      row_index={group_idx}
                      col_index={col_index}
                      edit_text={get_edit_text(@edit_text, col[:name], group, lines)}
                    />
                  <% true -> %>
                    <%= case col[:name] do %>
                      <% "line-num" -> %>
                        <%= if lines == [] do %>
                          0
                        <% else %>
                          <%= if length(lines) == 1 do %>
                            <%= List.first(lines).line_number %>
                          <% else %>
                            <%= "#{List.first(lines).line_number}-#{List.last(lines).line_number}" %>
                          <% end %>
                        <% end %>
                      <% "content" -> %>
                        <pre class="whitespace-pre-wrap"><code><%= Enum.map_join(lines, "\n", & &1.content) %></code></pre>
                      <% "note" -> %>
                        <div class={if(chunk, do: "text-gray-900", else: "text-gray-400")}>
                          <%= chunk && chunk.note || "No note" %>
                        </div>
                    <% end %>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

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


  attr :row_index, :integer, required: true
  attr :col_index, :integer, required: true
  attr :group, :any, required: true
  attr :col, :map, required: true
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

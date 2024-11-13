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
  attr :chunks, :list
  attr :row_click, :any, default: nil

  slot :col, required: true do
    attr :label, :string
    attr :name, :string
    attr :editable, :boolean
    attr :deletable, :boolean
  end

  def anno_grid(assigns) do
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
          <div :for={{row, row_index} <- Enum.with_index(@rows)}
            role="row"
            class={[
              "grid grid-cols-[80px_1fr_1fr]",
              "group hover:bg-zinc-50",
              is_selected?(@selection, row.id) && "bg-blue-50",
              row_index != length(@rows) - 1 && "border-b"
            ]}>
            <div
              :for={{col, col_index} <- Enum.with_index(@col)}
              tabindex="-1"
              role="gridcell"
              data-deletable={inspect is_deletable?(col)}
              data-focused={@focused_cell == {row_index, col_index}}
              class={[
                "p-3 min-h-[3rem]",
                col_index != length(@col) - 1 && "border-r",
                @focused_cell == {row_index, col_index} && "ring-2 ring-blue-500",
                col[:name] == "note" && "relative group",
                col[:editable] && "hover:cursor-pointer hover:bg-zinc-100/50"
              ]}
              phx-click={@row_click && @row_click.(row_index, col, col_index)}
            >
              <%= cond do %>
                <% @editing == {to_string(row_index), to_string(col_index)} -> %>
                  <.editor
                    row={row}
                    col={col}
                    row_index={row_index}
                    col_index={col_index}
                    edit_text={get_edit_text(@edit_text, col[:name], row, @chunks)}
                  />
                <% col[:name] == "note" -> %>
                  <%= case get_chunk_note(@chunks, row.id) do %>
                    <% nil -> %>
                      <div class="text-gray-400">No note</div>
                    <% note -> %>
                      <div class="text-gray-900"><%= note %></div>
                  <% end %>
                <% true -> %>
                  <%= render_slot(col, row) %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  attr :row_index, :integer, required: true
  attr :col_index, :integer, required: true
  attr :row, :any, required: true
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

  defp is_selected?(%{start_line: start_id, end_line: end_id}, line_id) when not is_nil(start_id) do
    line_id >= min(start_id, end_id) and line_id <= max(start_id, end_id)
  end
  defp is_selected?(_, _), do: false

  # Helper function to handle the default value for deletable
  defp is_deletable?(col) do
    case col[:deletable] do
      nil -> false  # Default value when attribute is not specified
      value ->
        value
    end
  end
  # Get the note for a line from its associated chunk
  defp get_chunk_note(chunks, line_id) do
    case Enum.find(chunks, fn chunk ->
      Enum.any?(chunk.chunk_lines, fn cl -> cl.line_id == line_id end)
    end) do
      nil -> nil
      chunk -> chunk.note
    end
  end

  defp get_chunk_id(chunks, line_id) do
    case Enum.find(chunks, fn chunk ->
      Enum.any?(chunk.chunk_lines, fn cl -> cl.line_id == line_id end)
    end) do
      nil -> nil
      chunk -> chunk.id
    end
  end

  defp get_edit_text(edit_text, col_name, row, chunks) do
    case col_name do
      "content" ->
        Logger.info("get_edit_text for content: #{inspect(row.content)}")
        row.content || ""
      "note" ->
        case edit_text do
          nil -> get_chunk_note(chunks, row.id) || ""
          "" -> get_chunk_note(chunks, row.id) || ""
          _ -> edit_text
        end
      _ -> ""
    end
  end
end

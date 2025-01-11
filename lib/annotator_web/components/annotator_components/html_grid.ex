defmodule AnnotatorWeb.AnnotatorComponents.HtmlGrid do
  use Phoenix.Component
  use AnnotatorWeb, :html
  alias AnnotatorWeb.AnnotatorComponents
  require Logger


  attr :chunk_groups, :list, required: true
  attr :lang, :string, default: ""
  attr :id, :string

  def html_grid(assigns) do
    ~H"""
    <div class="annotated-content-container">
      <.ro_grid
        chunk_groups={@chunk_groups}
        lang={@lang}
        collection_id={@id}
      >
        <:col name="content" label="Content"></:col>
        <:col name="note" label="Note"></:col>
      </.ro_grid>
    </div>
    """
  end

  attr :chunk_groups, :list, required: true
  attr :lang, :string, default: ""
  attr :collection_id, :string, required: true

  slot :col, required: true do
    attr :label, :string, required: true
    attr :name, :string, required: true
  end

  def ro_grid(assigns) do
    ~H"""
    <div
    class="subgrid-holder annotated-content"
    role="grid"
    tabindex="0"
    id={"annotated-content-#{@collection_id}"}
    phx-hook="GridNav" >
      <div role="rowgroup" class="subgrid-holder">
        <div role="row" class="subgrid-holder row-container">
          <div :for={col <- @col} role="columnheader" class="columnheader">
            <%= col[:label] %>
          </div>
        </div>
      </div>
      <div role="rowgroup" class="subgrid-holder">
        <%= for {{chunk, lines}, row_index} <- Enum.with_index(@chunk_groups) do %><div
            role="row"
            class="subgrid-holder row-container"
            style={AnnotatorComponents.rowspanstyle(lines)}
            ><%= for {col, col_index} <- Enum.with_index(@col) do %><div
                role="gridcell"
                tabindex="-1"
                id={"cell-#{row_index}-#{col_index}"}
                data-col-index={col_index}
                data-row-index={row_index}
                aria-label={AnnotatorComponents.get_aria_label(col, lines, chunk)}
                class={[
                  "grid-cell",
                  col[:name],
                  col_index != length(@col) - 1 && "border-r"
                ]}
                style={AnnotatorComponents.rowspanstyle(lines)}
                >
                <.static_cell_content
                  col={col}
                  row_index={row_index}
                  col_index={col_index}
                  chunk={chunk}
                  row_lines={lines}
                  lang={@lang}
                />
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
  """
  end

  attr :col, :any, required: true
  attr :chunk, :any
  attr :row_lines, :list
  attr :row_index, :string
  attr :col_index, :string
  attr :lang, :string, default: ""

  def static_cell_content(assigns) do
    ~H"""
    <%= case @col[:name] do %>
      <% "line-num" -> %>
        <div class="line-numbers flex flex-col">
          <%= for line <- Enum.sort(@row_lines, &(&1.line_number <= &2.line_number)) do %>
            <pre><code><%= line.line_number %></code></pre>
          <% end %>
        </div>
      <% "content" -> %>
        <div
            class="content ml-2 flex flex-col"
            role="presentation"
            phx-click={JS.focus(to: "#cell-#{@row_index}-#{@col_index}")}
            phx-value-row={@row_index}
            phx-value-col={@col_index}
          >
          <%= for line <- @row_lines do %>
              <pre class="whitespace-pre-wrap add-number" data-number={line.line_number}><code class={"language-#{@lang}"} ><%= raw line.content %></code></pre>
          <% end %>
        </div>
      <% "note" -> %>
        <div class="py-2 px-4">
          <%= Phoenix.HTML.raw Earmark.as_html!(@chunk.note, breaks: true) || "No note" %>
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

end

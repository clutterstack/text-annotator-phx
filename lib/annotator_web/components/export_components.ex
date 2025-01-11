defmodule AnnotatorWeb.ExportComponents do
  use Phoenix.Component
  use AnnotatorWeb, :html
  import AnnotatorWeb.AnnotatorComponents

  attr :chunk_groups, :list, required: true
  attr :lang, :string, default: ""
  attr :id, :string

  def html_divs(assigns) do
    ~H"""
    <div class="grid grid-cols-[4fr_3fr]">
      <.anno_grid
        mode="read-only"
        chunk_groups={@chunk_groups}
        lang={@lang}
        collection_id={@id}
      >
        <:col name="content" label="Content"></:col>
        <:col name="note" label="Note"></:col>
      </.anno_grid>
    </div>
    """
  end

  attr :chunk_groups, :list, required: true

  def html_table(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <style>
          .annotated-code {
                  width: 100%;
                  border-collapse: collapse;
                  margin: 2em 0;
              }

          .annotated-code th,
          .annotated-code td {
              border: 1px solid #ddd;
              padding: 8px;
              vertical-align: top;
          }

          .annotated-code th {
              background-color: #f5f5f5;
              text-align: left;
              font-weight: 600;
          }

          .line-numbers {
              user-select: none;
              text-align: right;
              color: #666;
              padding-right: 1em;
              white-space: pre;
              width: 1%;
              /*font-family: ui-monospace, monospace;*/

          }

          .content pre {
              /*margin: 0;*/
              white-space: pre-wrap;
          }

          .content code {
            /*  font-family: ui-monospace, monospace;*/
          }

          .notes {
              width: 30%;
              background-color: #fafafa;
          }

          /* Ensure notes align with their code when spanning multiple rows */
          .notes[rowspan] {
              vertical-align: top;
          }

          /* Zebra striping for better readability */
          .annotated-code tbody tr:nth-child(even) {
              background-color: #fafafa;
          }
        </style>
      </head>
      <body>
        <table class="annotated-code">
          <thead>
            <tr>
              <th scope="col">Line</th>
              <th scope="col">Content</th>
              <th scope="col">Notes</th>
            </tr>
          </thead>
          <tbody>
            <%= for {chunk, lines} <- @chunk_groups do %>
              <tr>
                <td class="line-numbers">
                    <pre><code><%= line_nums(%{lines: lines}) %></code></pre>
                </td>
                <td class="content">
                    <pre><code><%=chunk_content(%{lines: lines, format: "html"}) %></code></pre>
                </td>
                <td class="notes" style={"grid-row-end: span #{Enum.count(lines)};"}>
                 <%= Phoenix.HTML.raw Earmark.as_html!(chunk.note, breaks: true) || "No note" %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </body>
    </html>
    """
  end

  def markdown_table(assigns) do
    ~H"""
    | Line | Content | Notes |
    |---|---|---|
    <%= for {chunk, lines} <- @chunk_groups do %>|<pre><code><%= line_nums(%{lines: lines}) %></code></pre> |<pre><code><%= chunk_content(%{lines: lines, format: "md"}) %></code></pre>| <%= chunk_note(%{paras: paras(chunk.note)}) %> |
    <% end %>
    """
  end

  defp line_nums(assigns) do
    ~H"""
      <%= for line <- Enum.drop(@lines, -1) do %><%= line.line_number %><br><% end %><%= for line <- Enum.take(@lines, -1) do %><%= line.line_number %><% end %>
    """
    # <%= Enum.map(@lines, fn line -> "  #{line.line_number}\n" end) %>
#
  end
  defp chunk_content(assigns) do
    ~H"""
      <%= for line <- Enum.drop(@lines, -1) do %><%= escape_if_md(line.content, @format) %><br><% end %><%= for line <- Enum.take(@lines, -1) do %><%= escape_if_md(line.content, @format) %><% end %>
    """
  end

  defp escape_if_md(string, format) do
    if format == "md" do
      string
      |> String.replace("|", "\|") # the first backslash escapes the second one which we need in the output to escape the pipe when the markdown itself gets interpreted
      |> String.replace("\\", "\\\\")
      # |> IO.puts()
    else
      string
      |> html_escape()
    end
  end

  defp chunk_note(assigns) do
    ~H"""
    <%= for para <- Enum.drop(@paras, -1) do%><%= para %><br><% end %><%= for para <- Enum.take(@paras, -1) do%><%= para %><% end%>
    """
  end

  defp paras(note), do: if(note != nil, do: String.split(note, "\n"), else: [""])

end

defmodule AnnotatorWeb.ExportComponents do
  use Phoenix.Component
  use AnnotatorWeb, :html

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
                  font-family: ui-monospace, monospace;
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
          }

          .content pre {
              margin: 0;
              white-space: pre-wrap;
          }

          .content code {
              font-family: ui-monospace, monospace;
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
                  <%= for line <- lines do %>
                    <%= line.line_number %><br />
                  <% end %>
                </td>
                <td class="content">
                  <%= for line <- lines do %>
                    <pre><code><%= line.content %></code></pre>
                  <% end %>
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
    <%= for {chunk, lines} <- @chunk_groups do %>|<pre><code><%= line_nums(%{lines: lines}) %></code></pre> |<pre><code><%= chunk_content(%{lines: lines}) %></code></pre>| <%= chunk_note(%{paras: paras(chunk.note)}) %> |
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
      <%= for line <- Enum.drop(@lines, -1) do %><%= html_escape line.content |> String.replace("|", "\\|") %><br><% end %><%= for line <- Enum.take(@lines, -1) do %><%= line.content |> String.replace("|", "\|") %><% end %>
    """
  end

  defp chunk_note(assigns) do
    ~H"""
    <%= for para <- Enum.drop(@paras, -1) do%><%= para %><br><% end %><%= for para <- Enum.take(@paras, -1) do%><%= para %><% end%>
    """
  end

  defp paras(note), do: if(note != nil, do: String.split(note, "\n"), else: [""])

end

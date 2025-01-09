defmodule AnnotatorWeb.AnnotatorComponents do
  use Phoenix.Component
  use AnnotatorWeb, :html
  import AnnotatorWeb.CoreComponents
  alias Phoenix.LiveView.JS
  require Logger

  attr :mode, :string, default: "read-only"
  attr :editing, :any, default: nil
  attr :selection, :any, default: nil
  # attr :lines, :list, required: true
  attr :chunk_groups, :list, required: true
  attr :lang, :string, default: ""
  attr :latestline, :string, default: nil
  attr :lang_form, :any
  attr :collection_id, :string, required: true

  slot :col, required: true do
    attr :label, :string
    attr :name, :string
    attr :editable, :boolean
    attr :deletable, :boolean
  end

  def anno_grid(assigns) do
    # Logger.info("lines assign: #{inspect assigns.lines}")
    Logger.info("anno_grid log: lang assign? #{inspect assigns.lang}")
    ~H"""
    <div
      class="w-full grid grid-cols-subgrid col-span-full items-start rounded-lg border"
      role="grid"
      tabindex="0"
      id={"annotated-content-#{@collection_id}"}
      phx-hook="GridNav"
      data-latestline={@latestline != nil && @latestline}
      data-mode={@mode}
    >
      <div role="rowgroup" class="grid grid-cols-subgrid col-span-full">
        <div role="row" class="grid grid-cols-subgrid col-span-full border-b bg-zinc-50">
          <div :for={col <- @col} role="columnheader" class="p-1 text-sm font-medium text-zinc-500">
            <%= col[:label] %>
          </div>
        </div>
      </div>

      <div role="rowgroup" class="grid grid-cols-subgrid col-span-full">
        <%= for {group, row_index} <- Enum.with_index(@chunk_groups) do %>
          <% {chunk, lines} = group %>
          <div
            role="row"
            class={
              [
                "grid grid-cols-subgrid col-span-full",
                "hover:bg-zinc-50",
                row_index != length(@chunk_groups) - 1 && "border-b",
              ]
            }
            style={rowspanstyle(lines)}
          >
            <%= for {col, col_index} <- Enum.with_index(@col) do %>
              <div
                role="gridcell"
                tabindex="-1"
                id={"cell-#{row_index}-#{col_index}"}
                data-col={col[:name]}
                data-col-index={col_index}
                data-row-index={row_index}
                data-first-line={if(lines != [], do: List.first(lines).line_number)}
                data-last-line={if(lines != [], do: List.last(lines).line_number)}
                data-chunk-id={chunk.id}
                data-selectable={col[:name] == "line-num"}
                data-deletable={col[:deletable]}
                aria-label={get_aria_label(col, lines, chunk)}
                class={[
                  "grid-cell z-30 focus:bg-fuchsia-400",
                  col[:name],
                  col_index != length(@col) - 1 && "border-r",
                  col[:editable] && @mode === "author" &&
                    "hover:cursor-pointer hover:bg-zinc-100/50 editable",
                  col[:name] in ["line-num", "content"] && "grid grid-rows-subgrid"
                ]}
                style={rowspanstyle(lines)}
              >
                <%= if @editing == {to_string(row_index), to_string(col_index)} do %>
                  <.editor
                    row_index={row_index}
                    col_name={col[:name]}
                    chunk_id={chunk.id}
                    edit_text={get_edit_text(col[:name], {chunk, lines}, lines)}
                    num_lines={length(lines)}
                  />
                <% else %>
                  <.cell_content
                    col={col}
                    row_index={row_index}
                    col_index={col_index}
                    chunk={chunk}
                    row_lines={lines}
                    lang={@lang}
                  />
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
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

  # defp rowspanclass(lines) do
  #   "row-span-#{Enum.count(lines)}"
  # end

  # We may have a few hundred lines in a chunk, so Tailwind's row-span-*
  # shortcuts that seem to go up to 12 aren't cutting it.
  defp rowspanstyle(lines) do
    "grid-row-end: span #{Enum.count(lines)};"
  end

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

      "content" ->
        "Content: #{Enum.map_join(lines, " ", & &1.content)}"

      "note" ->
        "Note: #{(chunk && chunk.note) || "No note"}"
    end
  end

  defp get_edit_text("content", _group, lines) do
    Enum.map_join(lines, "\n", & &1.content)
  end

  defp get_edit_text("note", {chunk, _lines}, _) do
    (chunk && chunk.note) || ""
  end

  defp get_edit_text(_, _, _), do: ""

  attr :col, :any, required: true
  attr :chunk, :any
  attr :row_lines, :list
  attr :selection, :any, default: nil
  attr :row_index, :string
  attr :col_index, :string
  attr :lang, :string, default: ""

  def cell_content(assigns) do
    ~H"""
    <%= case @col[:name] do %>
      <% "line-span" -> %>
        <div>
          <%= if @row_lines == [] do %>
            <%= "0" %>
          <% else %>
            <%= case length(@row_lines) do %>
              <% 1 -> %>
                <%= List.first(@row_lines).line_number %>
              <% _ -> %>
                <%= "#{List.first(@row_lines).line_number}-#{List.last(@row_lines).line_number}" %>
            <% end %>
          <% end %>
        </div>
      <% "line-num" -> %>
        <%= for line <- Enum.sort(@row_lines, &(&1.line_number <= &2.line_number)) do %>
          <div
            class={[
              "line-#{line.line_number}",
              "line-number hover:bg-zinc-200/100 focus:bg-fuchsia-400 rounded cursor-pointer z-40 min-h-4"
            ]}
            role="button"
            tabindex="-1"
            data-line-number={line.line_number}
            data-selectable="true"
            aria-selected={is_line_selected?(line, @selection)}
          >
            <span><pre><code><%= line.line_number %></code></pre></span>
          </div>
        <% end %>
      <% "content" -> %>
        <%= for line <- @row_lines do %>
          <div
            class="content-line ml-2"
            role="presentation"
            phx-click={JS.focus(to: "#cell-#{@row_index}-#{@col_index}")}
            phx-value-row={@row_index}
            phx-value-col={@col_index}
          >
            <pre class="whitespace-pre-wrap"><code class={"language-#{@lang}"}><%= raw highlight_elixir(line.content) %></code></pre>
          </div>
        <% end %>
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

  defp highlight_elixir(content) do
    if is_binary(content) do
      content |> Makeup.highlight_inner_html()
    else
      ""
    end
  end

  defp is_line_selected?(line, selection) when not is_nil(selection) do
    line.line_number >= min(selection.start_line, selection.end_line) &&
      line.line_number <= max(selection.start_line, selection.end_line)
  end

  defp is_line_selected?(_, _), do: false

  attr :row_index, :integer, required: true
  # attr :col_index, :integer, required: true
  attr :col_name, :string, required: true
  attr :chunk_id, :string, required: true
  # attr :group, :any, required: true
  # attr :col, :map, required: true
  attr :edit_text, :string, required: true
  attr :num_lines, :integer, required: true

  def editor(assigns) do
    ~H"""
    <div
      id={"editor-#{@row_index}-#{@col_name}"}
      class="min-h-[3rem]"
      phx-hook="EditKeys"
      data-row-index={@row_index}
      data-col-name={@col_name}
      data-chunk-id={@chunk_id}
      style={"grid-row-end: span #{@num_lines}"}
    >
      <textarea
        class={"editor-#{@row_index}-#{@col_name} block w-full h-full min-h-[6rem] p-2 border rounded"}
        name="value"
        phx-debounce="200"
        autofocus
      ><%= @edit_text %></textarea>
    </div>
    """
  end

  @doc """
  Simplification of the core simple_form

  ## Examples
        <.name_form for={@name_form} phx-submit="rename_collection">
          <.name_input field={@name_form[:name]} />
          <.button aria-label="Rename collection" class="text-sm bg-zinc-400 font-light" phx-disable-with="Renaming...">Rename</.button>
        </.name_form>
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true

  def name_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="mt-6 bg-white flex">
        <%= render_slot(@inner_block, f) %>
      </div>
    </.form>
    """
  end


  @doc """
  Simplification of the core simple_form for highlighting language selection

  ## Examples
        <.horiz_form for={@name_form} phx-submit="rename_collection">
          <.horiz_input field={@name_form[:name]} />
          <.button aria-label="Rename collection" class="text-sm bg-zinc-400 font-light" phx-disable-with="Renaming...">Rename</.button>
        </.horiz_form>
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true

  def horiz_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="flex">
        <%= render_slot(@inner_block, f) %>
      </div>
    </.form>
    """
  end

  @doc """
    A text input for collection name. A copy of the
    core input component just to change styles.
  """

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
              range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def name_input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> name_input()
  end
  def name_input(assigns) do
    ~H"""
    <div class="flex w-72">
      <label :if={@label} for={@id} ><%= @label %></label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 block rounded-lg text-2xl text-zinc-900 focus:ring-0 py-0 pl-0 pr-5 w-full",
          @errors == [] && "border-transparent hover:border-zinc-400 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
    A text input for collection name. A copy of the
    core input component just to change styles.
  """

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
              range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def horiz_input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> horiz_input()
  end
  def horiz_input(assigns) do
    ~H"""
    <div class="flex">
      <label :if={@label} for={@id} ><%= @label %></label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 py-0 block rounded-lg text-sm text-zinc-900 focus:ring-0",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def new_collection_modal(assigns) do
    ~H"""
    <.modal id="collection-name-modal" show={true}>
      <.simple_form for={@form} phx-submit="create_collection">
        <.input field={@form[:name]} label="Collection Name" required />
        <:actions>
          <.button phx-disable-with="Creating...">Create Collection</.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

end

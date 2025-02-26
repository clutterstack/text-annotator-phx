defmodule AnnotatorWeb.TextAnnotatorLive do
  use AnnotatorWeb, :live_view
  import Annotator.SharedHelpers
  import AnnotatorWeb.AnnotatorComponents
  alias AnnotatorWeb.AnnotatorComponents.HtmlGrid
  alias Annotator.Lines
  require Logger

  def mount(%{"id" => id}, _session, socket) do
    case Lines.get_collection_with_assocs(id) do
      nil ->
        Logger.info("in TextAnnotatorLive, no collection matched id")

        {:ok,
         socket
         |> put_flash(:error, "Collection not found")
         |> push_navigate(to: ~p"/collections")}

      collection ->
        # Get unique chunks from lines, maintaining order
        # chunks = get_collection_chunks(collection.lines)
        # May want mode to be an assign too...certainly if we're going to
        # change it in the UI...though maybe we won't.
        Logger.info("in TextAnnotatorLive mount function, lang is #{collection.lang}")
        {:ok,
         assign(socket,
          collection: collection,
          chunk_groups: get_chunk_groups(collection.lines),
          editing: nil,
          mode: "author",
          lang: collection.lang,
          name_form: to_form(%{"name" => collection.name}),
          lang_form: to_form(%{"lang" => collection.lang}),
          latestline: nil
         )}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       collection: nil,
       editing: [0, 1],
       name_form: to_form(%{"name" => ""}),
       lang_form: to_form(%{"lang" => ""}),
       mode: "author"
     )}
  end

  def render(assigns) do
    # Logger.info("running render fn of textAnnotatorLive; lang assign is #{assigns.lang}. collection.lang is #{assigns.collection.lang}.")

    ~H"""
    <div id="collection-container" class="w-full space-y-2">
          <a class="inline-block" href="/" class="font-lg font-bold hover:text-zinc-700">&laquo; Collections</a>
        <.name_form for={@name_form} phx-submit="rename_collection">
          <.name_input field={@name_form[:name]}/>
          <.button class="self-center" aria-label="Rename collection" phx-disable-with="Renaming...">Rename</.button>
        </.name_form>
      <div class="flex justify-between">
        <.mode_switcher ro_mode={@mode === "read-only"} />
        <.horiz_form for={@lang_form} phx-submit="set_collection_lang">
          <.horiz_input field={@lang_form[:lang]} />
          <.button aria-label="Set language" class="text-sm font-light ml-2" phx-disable-with="Setting language">Set language</.button>
        </.horiz_form>
      </div>

      <div class={["grid", @mode !== "read-only" && "grid-cols-[min-content_4fr_3fr]" || "grid-cols-[4fr_3fr]"]}>
        <.anno_grid :if={@mode !== "read-only"}
          mode={@mode}
          chunk_groups={@chunk_groups}
          editing={@editing}
          lang={@lang}
          latestline={@latestline}
          collection_id={@collection.id}
        >
          <:col name="line-num" label="Line" editable={false} deletable={false}></:col>
          <:col name="content" label="Content" editable={true} deletable={true}></:col>
          <:col name="note" label="Note" editable={true} deletable={false}></:col>
        </.anno_grid>
        <HtmlGrid.ro_grid :if={@mode === "read-only"}
          chunk_groups={@chunk_groups}
          lang={@lang}
          collection_id={@collection.id}
          >
          <:col name="content" label="Content"></:col>
          <:col name="note" label="Note"></:col>
        </HtmlGrid.ro_grid>
      </div>
      <div class="flex justify-between">
        <.link navigate={~p"/collections/#{@collection.id}/export/html"}>Export HTML divs</.link>
        <.link navigate={~p"/collections/#{@collection.id}/export/md_dl"}>Export Markdown definition list</.link>
        <.link navigate={~p"/collections/#{@collection.id}/export/html_grid"}>Export HTML grid</.link>
        <.link navigate={~p"/collections/#{@collection.id}/export/html_table"}>Export HTML table</.link>
        <.link navigate={~p"/collections/#{@collection.id}/export/md"}>Export Markdown table</.link>
      </div>

      <div :if={@mode !== "read-only"} class="mt-4 text-sm text-gray-600 space-y-0" role="complementary" aria-label="Keyboard interaction">
      <p><strong>Keyboard interaction</strong></p>
      <p>To navigate between grid cells, use arrow keys.</p>
      <p>To edit a focused content or note grid cell, press <kbd>Enter</kbd>.</p>
      <p>To split or merge grid rows:</p>
      <p>    Enter line-number navigation mode by pressing <kbd>Enter</kbd> with a line-numbers cell focused.</p>
      <p>    Use up and down arrow keys to move between line numbers.</p>
      <p>    To begin a selection at a focused line number, press <kbd>V</kbd> (that's <kbd>Shift</kbd>-<kbd>v</kbd>).</p>
      <p>    To expand or contract the selection, use the up and down arrow keys.</p>
      <p>    To submit the selection, press <kbd>Ctrl</kbd>-<kbd>Enter</kbd> or <kbd>Cmd~</kbd>-<kbd>Enter</kbd>.</p>
      <p>    To clear and cancel the selection, press <kbd>Esc</kbd>.</p>
    </div>


    <div :if={@mode !== "read-only"} class="mt-4 text-sm text-gray-600 space-y-0" role="complementary" aria-label="Mouse interactions">
      <p><strong>Mouse interaction</strong></p>
      <p>To focus a content or note grid cell, click it.</p>
      <p>To edit a focused content or note grid cell, click it.</p>
      <p>To split or merge grid rows, click and drag line numbers. Clicking a single line number gives that line its own row.</p>
      <p>To cancel a line-number range selection, mouseup outside of the line-numbers column</p>
    </div>
    </div>
    """
  end

  def handle_event("start_edit", %{"row_index" => row_index, "col_index" => col_index}, socket) do
    Logger.info("in start_edit handler")
    row_index_str = ensure_string(row_index)
    col_index_str = ensure_string(col_index)

    case col_index_str do
      # Content column
      "1" ->
        Logger.info(
          "start_edit in content cell; should start editing {#{row_index_str}, #{col_index_str}}"
        )

        # Logger.info("check line.content: #{line.content}")
        {:noreply, assign(socket, editing: {row_index_str, col_index_str})}

      # Note column
      "2" ->
        Logger.info(
          "start_edit in note cell; at row_index_str {#{row_index_str}} and col_index_str {#{col_index_str}}"
        )

        {:noreply, assign(socket, editing: {row_index_str, col_index_str})}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    Logger.debug("cancel_edit handler triggered")

    {:noreply,
     assign(socket,
       editing: nil
     )}
  end

  def handle_event("update_cell",
        %{"chunk_id" => chunk_id, "col_name" => "content", "value" => content},
        socket
      ) do
    Logger.debug(
      "got an update_cell event to handle. chunk_id: #{chunk_id}, col_name: \'content\', value: #{content}"
    )

    # Ecto's going to expect chunk_id (which is a foreign key on the lines table) to be an integer:
    chunk_id_int = ensure_num(chunk_id)
    # row_num = if is_binary(row_index), do: String.to_integer(row_index), else: row_index
    case Lines.update_content(socket.assigns.collection.id, chunk_id_int, content) do
      {:ok, collection} ->
        # collection = Lines.get_collection_with_assocs(socket.assigns.collection.id)
        {:noreply,
         assign(socket,
           collection: collection,
           chunk_groups: get_chunk_groups(collection.lines),
           editing: nil,
           latestline: nil
         )}

      {:error, changeset} ->
        {:noreply, socket |> put_flash(:error, error_to_string(changeset))}
    end
  end

  def handle_event("update_cell",
        %{"chunk_id" => chunk_id, "col_name" => "note", "value" => note},
        socket
      ) do
    Logger.info(
      "got an update_cell event to handle. chunk_id: #{chunk_id}, col_name: \'note\', value: #{note}"
    )

    Logger.info("it's in the note column")
    chunk_id_int = ensure_num(chunk_id)

    case Lines.update_note_by_id(chunk_id_int, note) do
      {:ok, _updated} ->
        collection = Lines.get_collection_with_assocs(socket.assigns.collection.id)

        {:noreply,
         assign(socket,
           collection: collection,
           chunk_groups: get_chunk_groups(collection.lines),
           editing: nil,
           latestline: nil
         )}

      {:error, changeset} ->
        {:noreply, socket |> put_flash(:error, error_to_string(changeset))}
    end
  end

  def handle_event("rechunk", %{"start" => chunk_start, "end" => chunk_end}, socket) do
    Logger.info("chunk_end given to rechunk is #{chunk_end}")
    collection_id = socket.assigns.collection.id

    Logger.info(
      "are chunk_start and chunk_end binaries? chunk_start: #{inspect(is_binary(chunk_start))}; #{inspect(is_binary(chunk_end))}"
    )

    Logger.info("Attempting to rechunk lines #{chunk_start} through #{chunk_end}")

    case Lines.split_or_merge_chunks(collection_id, chunk_start, chunk_end) do
      {:ok, _} ->
        # Get collection fresh from the database
        collection = Lines.get_collection_with_assocs(collection_id)
        chunk_groups = get_chunk_groups(collection.lines)
        # Logger.debug("After rechunk - line count: #{length(collection.lines)}")
        # Logger.debug("After rechunk - chunks: #{inspect(Enum.map(collection.lines, & &1.chunk_id))}")
        {
          :noreply,
          socket
          |> assign(
            collection: collection,
            # lines: collection.lines,
            chunk_groups: chunk_groups,
            # selection: nil,
            # Update this just to be on the safe side
            editing: nil,
            latestline: chunk_end
          )
          # |> scroll_to_chunk(chunk_start)
        }

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, error_to_string(reason))}
        #  |> assign(selection: nil)}
    end
  end

  def handle_event("rename_collection", %{"name" => name}, socket) do
    case rename_collection(socket.assigns.collection.id, name) do
      {:ok, collection} ->
        renamed_collection = Lines.get_collection_with_assocs(collection.id)

        {:noreply,
         assign(socket,
           collection: renamed_collection
           # chunk_groups: get_chunk_groups(new_collection.lines),
           # editing: {"0", "2"}, # Start in edit mode for content
           # selection: nil
         )
         |> put_flash(:info, "Collection renamed successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, error_to_string(changeset))
         |> assign(form: to_form(Map.put(socket.assigns.form.data, "name", name)))} # this came from an LLM. I think it puts the name back into the form for another try...
    end
  end

  def handle_event("set_collection_lang", %{"lang" => lang}, socket) do
    # {:noreply, socket |> assign(lang: lang)}
    ## TODO: make sure this makes sense and activate it once schema can support it
    Logger.info("set_collection_lang triggered")
    case set_lang(socket.assigns.collection.id, lang) do
      {:ok, _collection} -> {:noreply, assign(socket, lang: lang)}
      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, error_to_string(changeset))
         |> assign(form: to_form(Map.put(socket.assigns.form.data, "lang", lang)))}
    end
  end

  def handle_event("toggle_mode", _params, socket) do
    mode = case socket.assigns.mode do
      "read-only" -> "author"
      "author" -> "read-only"
    end
    {:noreply, assign(socket, mode: mode)}
  end

  # # TODO: change the schema to store a language for highlighting
  defp set_lang(id, lang) do
    collection = Lines.get_collection!(id)
    Lines.update_collection(collection, %{lang: lang})
  end

  defp rename_collection(id, name) do
    collection = Lines.get_collection!(id)
    Lines.update_collection(collection, %{name: name})
  end

  defp ensure_string(value) do
    if !is_binary(value) do
      Logger.info("Converting numerical value to string.")
      to_string(value)
    else
      value
    end
  end

  defp ensure_num(value) do
    if is_binary(value) do
      Logger.info("Converting string to integer.")
      String.to_integer(value)
    else
      value
    end
  end

  defp error_to_string(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, "; ")}" end)
    |> Enum.join("\n")
  end
end

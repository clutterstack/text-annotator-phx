defmodule AnnotatorWeb.TextAnnotatorLive do
  use AnnotatorWeb, :live_view
  import Annotator.SharedHelpers
  import AnnotatorWeb.AnnotatorComponents
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
        {:ok,
         assign(socket,
           collection: collection,
           chunk_groups: get_chunk_groups(collection.lines),
           editing: nil,
           selection: nil,
           form: to_form(%{"name" => collection.name})
         )}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       collection: nil,
       editing: [0, 1],
       selection: nil,
       form: to_form(%{"name" => ""})
     )}
  end

  def render(assigns) do
    ~H"""
    <.back navigate={~p"/collections"}>Back to collections</.back>
    <div class="w-full">
      <.new_collection_modal :if={!@collection} form={@form} />

      <div :if={@collection} class="space-y-8">
        <div class="mx-auto max-w-4xl">
          <.name_form for={@form} phx-submit="rename_collection">
            <.input class="grow" field={@form[:name]} label="Collection Name" required />
            <:actions>
              <.button phx-disable-with="Renaming...">Rename collection</.button>
            </:actions>
          </.name_form>
        </div>
        <.anno_grid
          mode="author"
          chunk_groups={@chunk_groups}
          editing={@editing}
          selection={@selection}
        >
          <:col name="line-span" label="Chunk lines" editable={false} deletable={false}></:col>
          <:col name="line-num" label="Line" editable={false} deletable={false}></:col>
          <:col name="content" label="Content" editable={true} deletable={true}></:col>
          <:col name="note" label="Note" editable={true} deletable={false}></:col>
        </.anno_grid>
        <.link navigate={~p"/collections/#{@collection.id}/export/html"}>View as HTML</.link>
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
      "2" ->
        Logger.info(
          "start_edit in content cell; should start editing {#{row_index_str}, #{col_index_str}}"
        )

        # Logger.info("check line.content: #{line.content}")
        {:noreply, assign(socket, editing: {row_index_str, col_index_str})}

      # Note column
      "3" ->
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

  def handle_event("cancel_selection", _params, socket) do
    Logger.debug("cancel_selection handler triggered")
    {:noreply, assign(socket, selection: nil)}
  end

  def handle_event(
        "update_cell",
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
           editing: nil
         )}

      {:error, changeset} ->
        {:noreply, socket |> put_flash(:error, error_to_string(changeset))}
    end
  end

  def handle_event(
        "update_cell",
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
           editing: nil
         )}

      {:error, changeset} ->
        {:noreply, socket |> put_flash(:error, error_to_string(changeset))}
    end
  end

  def handle_event("rechunk", _, socket) do
    Logger.info("socket.assigns.selection: #{inspect(socket.assigns.selection)}")

    %{start_line: chunk_start, end_line: chunk_end} = socket.assigns.selection
    collection_id = socket.assigns.collection.id

    Logger.debug(
      "are chunk_start and chunk_end binaries? chunk_start: #{inspect(is_binary(chunk_start))}; #{inspect(is_binary(chunk_end))}"
    )

    # Log before state
    # collection_before = Lines.get_collection_with_assocs(collection_id)
    # Logger.info("Before rechunk - chunks: #{inspect(Enum.map(collection_before.lines, & &1.chunk_id))}")
    # Logger.info("Attempting to rechunk lines #{chunk_start} through #{chunk_end}")

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
            selection: nil,
            # Update this just to be on the safe side
            editing: nil
          )
          # |> scroll_to_chunk(chunk_start)
        }

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, error_to_string(reason))
         |> assign(selection: nil)}
    end
  end

  def handle_event("start_selection", %{"start" => start_line, "end" => end_line}, socket) do
    {:noreply,
     assign(socket,
       selection: %{
         start_line: start_line,
         end_line: end_line
       }
     )}
  end

  def handle_event("update_selection", %{"start" => start_line, "end" => end_line}, socket) do
    Logger.info("updating line selection to #{start_line} - #{end_line}")

    {:noreply,
     assign(socket,
       selection: %{
         start_line: start_line,
         end_line: end_line
       }
     )}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, selection: nil)}
  end

  def handle_event("create_collection", %{"name" => name}, socket) do
    case new_collection(name) do
      {:ok, collection} ->
        new_collection = Lines.get_collection_with_assocs(collection.id)
        new_id = collection.id

        {:noreply,
         socket
         |> assign(
           collection: new_collection,
           chunk_groups: get_chunk_groups(new_collection.lines),
           # Start in edit mode for content
           editing: {"0", "2"},
           selection: nil
         )
         |> push_navigate(to: ~p"/collections/#{new_id}")
         |> put_flash(:info, "Collection created successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, error_to_string(changeset))
         |> assign(form: to_form(Map.put(socket.assigns.form.data, "name", name)))}
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
         |> assign(form: to_form(Map.put(socket.assigns.form.data, "name", name)))}
    end
  end

  defp new_collection(name) do
    {:ok, new_collection} = Lines.create_collection(%{name: name})
    Lines.append_chunk(new_collection.id)
    {:ok, new_collection}
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

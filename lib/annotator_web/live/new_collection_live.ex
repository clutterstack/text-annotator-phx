defmodule AnnotatorWeb.NewCollectionLive do
  use AnnotatorWeb, :live_view
  import AnnotatorWeb.AnnotatorComponents
  alias Annotator.Lines
  require Logger

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
    <.new_collection_modal form={@form} />
    """
  end

  def handle_event("create_collection", %{"name" => name}, socket) do
    case new_collection(name) do
      {:ok, collection} ->
        # new_id = collection.id

        {:noreply,
         socket
         |> put_flash(:info, "Collection created successfully")
         |> push_navigate(to: ~p"/collections/#{collection.id}")}

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

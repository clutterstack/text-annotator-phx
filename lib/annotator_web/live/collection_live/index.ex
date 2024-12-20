defmodule AnnotatorWeb.CollectionLive.Index do
  use AnnotatorWeb, :live_view
  alias Annotator.Lines

  def mount(_params, _session, socket) do
    collections = Lines.list_collections()

    {:ok,
     assign(socket,
       collections: collections,
       page_title: "Collections"
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">Annotated Collections</h1>
        <.link
          navigate={~p"/collections/new"}
          class="rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
        >
          New Collection
        </.link>
      </div>

      <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-zinc-200">
          <thead class="bg-zinc-50">
            <tr>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider"
              >
                Name
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider"
              >
                ID
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider"
              >
                Lines
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider"
              >
                Created
              </th>
              <th scope="col" class="relative px-6 py-3">
                <span class="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-zinc-200">
            <tr :for={collection <- @collections} id={"collection-#{collection.id}"}>
              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-zinc-900">
                <.link navigate={~p"/collections/#{collection.id}"} class="hover:text-blue-600">
                  <%= collection.name %>
                </.link>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-zinc-900">
                <.link navigate={~p"/collections/#{collection.id}"} class="hover:text-blue-600">
                  <%= collection.id %>
                </.link>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-500">
                <%= Lines.Collection.lines_count(collection) %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-500">
                <%= Calendar.strftime(collection.inserted_at, "%Y-%m-%d-%H:%M") %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <div class="flex justify-end gap-3">
                  <.link
                    phx-click={JS.push("delete", value: %{id: collection.id})}
                    data-confirm="Are you sure?"
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </.link>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  def handle_event("delete", %{"id" => id}, socket) do
    collection = Lines.get_collection!(id)
    {:ok, _} = Lines.delete_collection(collection)

    collections = Lines.list_collections()
    {:noreply, assign(socket, collections: collections)}
  end
end

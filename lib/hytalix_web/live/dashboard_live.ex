defmodule HytalixWeb.DashboardLive do
  use HytalixWeb, :live_view

  alias Hytalix.Servers.Manager

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Hytalix.PubSub, "servers")

    {:ok, assign(socket, servers: Manager.list_servers())}
  end

  def handle_info({:server_started, _id}, socket) do
    {:noreply, assign(socket, servers: Manager.list_servers())}
  end

  def handle_info({:server_stopped, _id}, socket) do
    {:noreply, assign(socket, servers: Manager.list_servers())}
  end

  def handle_event("create_test_server", _params, socket) do
    id = "server_#{:rand.uniform(1000)}"
    Manager.start_server(id)
    {:noreply, socket}
  end

  def handle_event("stop_server", %{"id" => id}, socket) do
    Manager.stop_server(id)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-extrabold tracking-tight">Server Management</h1>
        <button phx-click="create_test_server" class="btn btn-primary">
          <.icon name="hero-plus-solid" class="size-4" /> New Test Instance
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for id <- @servers do %>
          <div class="card bg-base-200 border border-base-300 shadow-sm hover:shadow-md transition-shadow">
            <div class="card-body">
              <div class="flex justify-between items-start">
                <div>
                  <h2 class="card-title text-primary">{id}</h2>
                  <div class="flex items-center gap-2 mt-1">
                    <span class="relative flex h-2 w-2">
                      <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-success opacity-75">
                      </span>
                      <span class="relative inline-flex rounded-full h-2 w-2 bg-success"></span>
                    </span>
                    <span class="text-xs font-mono opacity-60 uppercase">Online</span>
                  </div>
                </div>
              </div>

              <div class="card-actions justify-end mt-6">
                <.link navigate={~p"/server/#{id}"} class="btn btn-sm btn-ghost">
                  Console
                </.link>
                <button
                  phx-click="stop_server"
                  phx-value-id={id}
                  class="btn btn-sm btn-error btn-soft"
                >
                  Stop
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%= if @servers == [] do %>
        <div class="text-center py-20 border-2 border-dashed border-base-300 rounded-box">
          <p class="text-base-content/50 italic">
            No instances running. Click "New Test Instance" to begin.
          </p>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end

defmodule HytalixWeb.ServerLive do
  use HytalixWeb, :live_view

  alias Hytalix.Servers.Manager

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hytalix.PubSub, "server:#{id}")
      Phoenix.PubSub.subscribe(Hytalix.PubSub, "servers")
    end

    logs = Manager.get_logs(id)
    running? = Manager.server_running?(id)

    log_items =
      logs
      |> Enum.reverse()
      |> Enum.with_index(fn text, idx -> %{id: idx, text: text} end)

    socket =
      socket
      |> assign(id: id, running?: running?)
      |> stream(:logs, log_items)

    {:ok, socket}
  end

  def handle_info({:new_log, text}, socket) do
    id = System.unique_integer([:positive])
    {:noreply, stream_insert(socket, :logs, %{id: id, text: text})}
  end

  def handle_info({:server_stopped, id}, socket) do
    if id == socket.assigns.id do
      {:noreply, assign(socket, running?: false)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:server_started, id}, socket) do
    if id == socket.assigns.id do
      {:noreply, assign(socket, running?: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("send_command", %{"command" => command}, socket) do
    Manager.send_command(socket.assigns.id, command)
    {:noreply, socket}
  end

  def handle_event("stop_server", _params, socket) do
    Manager.stop_server(socket.assigns.id)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" /> Back
          </.link>
          <h1 class="text-2xl font-bold">{@id}</h1>
          <div class="flex items-center gap-2">
            <%= if @running? do %>
              <span class="badge badge-success gap-1">
                <span class="relative flex h-2 w-2">
                  <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-success opacity-75">
                  </span>
                  <span class="relative inline-flex rounded-full h-2 w-2 bg-success"></span>
                </span>
                Online
              </span>
            <% else %>
              <span class="badge badge-error">Offline</span>
            <% end %>
          </div>
        </div>

        <%= if @running? do %>
          <button phx-click="stop_server" class="btn btn-error btn-sm">
            <.icon name="hero-stop" class="size-4" /> Stop Server
          </button>
        <% end %>
      </div>

      <div class="bg-base-300 rounded-box overflow-hidden">
        <div class="bg-base-200 px-4 py-2 border-b border-base-300 flex items-center gap-2">
          <.icon name="hero-command-line" class="size-4 opacity-60" />
          <span class="text-sm font-medium opacity-60">Console</span>
        </div>

        <div
          id="logs"
          phx-update="stream"
          class="h-96 overflow-y-auto p-4 font-mono text-sm bg-black text-green-400 space-y-0.5"
        >
          <p :for={{dom_id, log} <- @streams.logs} id={dom_id} class="whitespace-pre-wrap">{log.text}</p>
        </div>

        <%= if @running? do %>
          <form phx-submit="send_command" class="border-t border-base-300 flex">
            <span class="px-4 py-3 text-green-400 font-mono bg-black">&gt;</span>
            <input
              type="text"
              name="command"
              placeholder="Enter command..."
              autocomplete="off"
              class="flex-1 px-2 py-3 bg-black text-green-400 font-mono focus:outline-none"
            />
            <button type="submit" class="px-4 py-3 bg-base-200 hover:bg-base-300 transition-colors">
              <.icon name="hero-paper-airplane" class="size-4" />
            </button>
          </form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end

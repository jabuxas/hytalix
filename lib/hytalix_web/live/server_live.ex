defmodule HytalixWeb.ServerLive do
  use HytalixWeb, :live_view

  alias Hytalix.Servers.Manager

  def mount(%{"id" => id}, _session, socket) do
    id = String.to_integer(id)
    server = Manager.get_server!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hytalix.PubSub, "server:#{id}")
      Phoenix.PubSub.subscribe(Hytalix.PubSub, "servers")
    end

    logs = Manager.get_logs(id)
    running? = Manager.server_running?(id)

    log_items =
      logs
      |> Enum.reverse()
      |> Enum.with_index(fn text, idx -> %{id: idx, html: parse_ansi(text)} end)

    socket =
      socket
      |> assign(id: id, server: server, running?: running?)
      |> stream(:logs, log_items)

    {:ok, socket}
  end

  def handle_info({:new_log, text}, socket) do
    log_id = System.unique_integer([:positive])
    {:noreply, stream_insert(socket, :logs, %{id: log_id, html: parse_ansi(text)})}
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

  # ANSI color code to CSS class mapping
  # Map ANSI color codes to CSS classes
  @ansi_colors %{
    # Standard colors
    "30" => "text-base-content/60",
    "31" => "text-error",
    "32" => "text-success",
    "33" => "text-warning",
    "34" => "text-info",
    "35" => "text-secondary",
    "36" => "text-accent",
    "37" => "text-base-content",
    # With reset prefix (0;XX)
    "0;31" => "text-error",
    "0;32" => "text-success",
    "0;33" => "text-warning",
    "0;34" => "text-info",
    # Bold (1;XX)
    "1;31" => "text-error font-bold",
    "1;32" => "text-success font-bold",
    "1;33" => "text-warning font-bold"
  }

  defp parse_ansi(text) when is_binary(text) do
    # Match both \e[XXm (real ANSI) and [XXm (stripped escape from Hytale logs)
    text
    |> then(&Regex.replace(~r/(?:\x1b)?\[([0-9;]*)m/, &1, fn _full, codes ->
      cond do
        codes == "" or codes == "0" -> "</span>"
        class = Map.get(@ansi_colors, codes) -> ~s(<span class="#{class}">)
        true -> ""
      end
    end))
    |> String.trim()
    |> Phoenix.HTML.raw()
  end

  defp parse_ansi(text), do: text

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" /> Back
          </.link>
          <h1 class="text-2xl font-bold">{@server.name}</h1>
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

      <div class="bg-base-200 rounded-box overflow-hidden border border-base-300">
        <div class="bg-base-300 px-4 py-2 border-b border-base-300 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <.icon name="hero-command-line" class="size-4 opacity-60" />
            <span class="text-sm font-medium opacity-60">Console</span>
          </div>
          <div class="flex items-center gap-2 text-xs opacity-50">
            <span class="badge badge-xs">Port {@server.port}</span>
            <span class="badge badge-xs">{@server.memory_max_mb}MB</span>
          </div>
        </div>

        <div
          id="logs"
          phx-update="stream"
          phx-hook="ScrollToBottom"
          class="h-[42rem] overflow-y-auto p-4 font-mono text-xs leading-relaxed bg-base-100 text-base-content space-y-0.5"
        >
          <div class="hidden only:flex items-center justify-center h-full opacity-50">
            <p>Waiting for logs...</p>
          </div>
          <p
            :for={{dom_id, log} <- @streams.logs}
            id={dom_id}
            class="whitespace-pre-wrap hover:bg-base-200 px-1 -mx-1 rounded transition-colors"
          >
            {log.html}
          </p>
        </div>

        <%= if @running? do %>
          <form phx-submit="send_command" class="border-t border-base-300 flex bg-base-200">
            <span class="px-4 py-3 text-primary font-mono font-bold">&gt;</span>
            <input
              type="text"
              name="command"
              placeholder="Enter command..."
              autocomplete="off"
              class="flex-1 px-2 py-3 bg-transparent font-mono focus:outline-none placeholder:opacity-40"
            />
            <button type="submit" class="px-4 py-3 hover:bg-base-300 transition-colors">
              <.icon name="hero-paper-airplane" class="size-4" />
            </button>
          </form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end

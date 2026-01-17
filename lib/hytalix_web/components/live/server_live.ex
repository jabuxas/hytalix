defmodule HytalixWeb.ServerLive do
  use HytalixWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Hytalix.PubSub, "server:#{id}")
    {:ok, assign(socket, id: id, logs: [])}
  end

  def handle_info({:new_log, text}, socket) do
    {:noreply, update(socket, :logs, fn logs -> [text | logs] |> Enum.take(100) end)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-4 bg-black text-green-400 font-mono h-96 overflow-y-scroll">
      <h2>monitoring hytale server: {@id}</h2>
      <div id="logs">
        <%= for log <- Enum.reverse(@logs) do %>
          <p>{log}</p>
        <% end %>
      </div>
    </div>
    """
  end
end

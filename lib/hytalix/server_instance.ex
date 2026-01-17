defmodule Hytalix.ServerInstance do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: {:global, opts[:id]})
  end

  @impl true
  def init(opts) do
    # port = Port.open({:spawn, "java -Xmx1G -jar hytale_server.jar"}, [:binary, :exit_status])
    port = Port.open({:spawn, "./mock_server.sh"}, [:binary, :exit_status])
    {:ok, %{port: port, id: opts[:id], logs: []}}
  end

  @impl true
  def handle_info({_port, {:data, text}}, state) do
    Phoenix.PubSub.broadcast(Hytalix.PubSub, "server:#{state.id}", {:new_log, text})
    {:noreply, state}
  end

  @impl true
  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.error("hytale server #{state.id} stopped with status :#{status}")
    {:stop, :normal, state}
  end
end

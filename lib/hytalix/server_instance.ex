defmodule Hytalix.ServerInstance do
  use GenServer
  require Logger

  def via_tuple(id), do: {:via, Registry, {Hytalix.ServerRegistry, id}}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:id]))
  end

  def stop(id) do
    case Registry.lookup(Hytalix.ServerRegistry, id) do
      [{pid, _}] -> GenServer.cast(pid, :stop_gracefully)
      [] -> :error
    end
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    Phoenix.PubSub.broadcast(Hytalix.PubSub, "manager", {:server_started, opts[:id]})
    # port = Port.open({:spawn, "java -Xmx1G -jar hytale_server.jar"}, [:binary, :exit_status])
    port = Port.open({:spawn, "./mock_server.sh"}, [:binary, :exit_status])
    {:ok, %{port: port, id: opts[:id], logs: []}}
  end

  @impl true
  def terminate(_reason, state) do
    Phoenix.PubSub.broadcast(Hytalix.PubSub, "manager", {:server_stopped, state.id})
    :ok
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

  def send_command(id, command) do
    if pid = :global.whereis_name(id) do
      GenServer.cast(pid, {:command, command})
    end
  end

  @impl true
  def handle_cast({:command, cmd}, state) do
    Port.command(state.port, "#{cmd}\n")
    {:noreply, state}
  end
end

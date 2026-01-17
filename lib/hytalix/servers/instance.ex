defmodule Hytalix.Servers.Instance do
  @moduledoc """
  GenServer that wraps an external Hytale server process.

  Handles stdin/stdout communication via Erlang ports and broadcasts
  log output via PubSub for real-time UI updates.
  """
  use GenServer, restart: :temporary
  require Logger

  @max_log_lines 100

  def via_tuple(id), do: {:via, Registry, {Hytalix.ServerRegistry, id}}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:id]))
  end

  def stop(id) do
    case Registry.lookup(Hytalix.ServerRegistry, id) do
      [{pid, _}] -> GenServer.cast(pid, :stop_gracefully)
      [] -> {:error, :not_found}
    end
  end

  def send_command(id, command) do
    case Registry.lookup(Hytalix.ServerRegistry, id) do
      [{pid, _}] -> GenServer.cast(pid, {:send_command, command})
      [] -> {:error, :not_found}
    end
  end

  def get_logs(id) do
    case Registry.lookup(Hytalix.ServerRegistry, id) do
      [{pid, _}] -> GenServer.call(pid, :get_logs)
      [] -> []
    end
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    Phoenix.PubSub.broadcast(Hytalix.PubSub, "servers", {:server_started, opts[:id]})

    port = Port.open({:spawn, "./mock_server.sh"}, [:binary, :exit_status, :use_stdio])

    {:ok, %{port: port, id: opts[:id], logs: []}}
  end

  @impl true
  def handle_call(:get_logs, _from, state) do
    {:reply, state.logs, state}
  end

  @impl true
  def handle_cast(:stop_gracefully, state) do
    Logger.info("Stopping server: #{state.id}")
    Port.command(state.port, "stop\n")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_command, command}, state) do
    Port.command(state.port, "#{command}\n")
    {:noreply, state}
  end

  @impl true
  def handle_info({_port, {:data, text}}, state) do
    Phoenix.PubSub.broadcast(Hytalix.PubSub, "server:#{state.id}", {:new_log, text})
    new_logs = [text | state.logs] |> Enum.take(@max_log_lines)
    {:noreply, %{state | logs: new_logs}}
  end

  @impl true
  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.warning("Hytale process #{state.id} exited with status: #{status}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:EXIT, _port, _reason}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    Phoenix.PubSub.broadcast(Hytalix.PubSub, "servers", {:server_stopped, state.id})

    if state.port && Port.info(state.port) do
      Port.close(state.port)
    end

    :ok
  end
end

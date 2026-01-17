defmodule Hytalix.Servers.Instance do
  @moduledoc """
  GenServer that wraps an external Hytale server process.

  Handles stdin/stdout communication via Erlang ports and broadcasts
  log output via PubSub for real-time UI updates.
  """
  use GenServer, restart: :temporary
  require Logger

  alias Hytalix.Servers.Server

  @max_log_lines 100

  def via_tuple(id), do: {:via, Registry, {Hytalix.ServerRegistry, id}}

  def start_link(opts) do
    server = opts[:server]
    GenServer.start_link(__MODULE__, server, name: via_tuple(server.id))
  end

  def stop(id) do
    id = normalize_id(id)

    case Registry.lookup(Hytalix.ServerRegistry, id) do
      [{pid, _}] -> GenServer.cast(pid, :stop_gracefully)
      [] -> {:error, :not_found}
    end
  end

  def send_command(id, command) do
    id = normalize_id(id)

    case Registry.lookup(Hytalix.ServerRegistry, id) do
      [{pid, _}] -> GenServer.cast(pid, {:send_command, command})
      [] -> {:error, :not_found}
    end
  end

  def get_logs(id) do
    id = normalize_id(id)

    case Registry.lookup(Hytalix.ServerRegistry, id) do
      [{pid, _}] -> GenServer.call(pid, :get_logs)
      [] -> []
    end
  end

  defp normalize_id(id) when is_binary(id), do: String.to_integer(id)
  defp normalize_id(id), do: id

  @impl true
  def init(%Server{} = server) do
    Process.flag(:trap_exit, true)

    Phoenix.PubSub.broadcast(Hytalix.PubSub, "servers", {:server_started, server.id})

    command = build_command(server)
    Logger.info("Starting server #{server.name} (#{server.id}): #{command}")

    port =
      Port.open({:spawn, command}, [
        :binary,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        {:cd, Path.dirname(server.server_jar_path)}
      ])

    {:ok,
     %{
       port: port,
       id: server.id,
       name: server.name,
       logs: []
     }}
  end

  defp build_command(%Server{} = server) do
    if String.ends_with?(server.server_jar_path, "mock_server.sh") do
      server.server_jar_path
    else
      Server.build_command(server)
    end
  end

  @impl true
  def handle_call(:get_logs, _from, state) do
    {:reply, state.logs, state}
  end

  @impl true
  def handle_cast(:stop_gracefully, state) do
    Logger.info("Stopping server: #{state.name} (#{state.id})")
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
    Logger.warning("Hytale process #{state.name} (#{state.id}) exited with status: #{status}")
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

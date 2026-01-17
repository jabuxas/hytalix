defmodule Hytalix.Servers.Manager do
  @moduledoc """
  Facade for managing Hytale server instances.

  Provides a clean API for starting, stopping, and querying server instances.
  """

  alias Hytalix.Servers.Instance

  @supervisor Hytalix.ServerSupervisor
  @registry Hytalix.ServerRegistry

  @doc """
  Starts a new server instance with the given id.
  """
  def start_server(id) do
    DynamicSupervisor.start_child(@supervisor, {Instance, id: id})
  end

  @doc """
  Gracefully stops a running server instance.
  """
  def stop_server(id) do
    Instance.stop(id)
  end

  @doc """
  Sends a command to a running server's stdin.
  """
  def send_command(id, command) do
    Instance.send_command(id, command)
  end

  @doc """
  Returns the log buffer for a server instance.
  """
  def get_logs(id) do
    Instance.get_logs(id)
  end

  @doc """
  Lists all currently running server instance IDs.
  """
  def list_servers do
    Registry.select(@registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Checks if a server with the given id is running.
  """
  def server_running?(id) do
    case Registry.lookup(@registry, id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end
end

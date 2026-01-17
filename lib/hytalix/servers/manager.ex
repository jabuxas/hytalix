defmodule Hytalix.Servers.Manager do
  @moduledoc """
  Facade for managing Hytale server instances.

  Provides a clean API for CRUD operations on server configs and
  starting/stopping/querying running server instances.
  """

  alias Hytalix.Repo
  alias Hytalix.Servers.{Instance, Server}
  import Ecto.Query

  @supervisor Hytalix.ServerSupervisor
  @registry Hytalix.ServerRegistry

  # ============================================================================
  # Database CRUD
  # ============================================================================

  @doc """
  Returns all server configurations.
  """
  def list_all_servers do
    Repo.all(Server)
  end

  @doc """
  Gets a server by ID. Raises if not found.
  """
  def get_server!(id), do: Repo.get!(Server, id)

  @doc """
  Gets a server by ID. Returns nil if not found.
  """
  def get_server(id), do: Repo.get(Server, id)

  @doc """
  Creates a new server configuration.
  """
  def create_server(attrs \\ %{}) do
    %Server{}
    |> Server.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a server configuration.
  """
  def update_server(%Server{} = server, attrs) do
    server
    |> Server.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a server configuration.
  """
  def delete_server(%Server{} = server) do
    Repo.delete(server)
  end

  @doc """
  Returns a changeset for tracking server changes.
  """
  def change_server(%Server{} = server, attrs \\ %{}) do
    Server.changeset(server, attrs)
  end

  # ============================================================================
  # Process Management
  # ============================================================================

  @doc """
  Starts a server instance from its database config or by database ID.
  """
  def start_server(%Server{} = server) do
    DynamicSupervisor.start_child(@supervisor, {Instance, server: server})
  end

  def start_server(id) when is_integer(id) do
    server = get_server!(id)
    start_server(server)
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
  def list_running_servers do
    Registry.select(@registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Checks if a server with the given id is running.
  """
  def server_running?(id) do
    id = if is_binary(id), do: String.to_integer(id), else: id

    case Registry.lookup(@registry, id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc """
  Returns servers marked for auto-start.
  """
  def list_auto_start_servers do
    from(s in Server, where: s.auto_start == true)
    |> Repo.all()
  end
end

defmodule Hytalix.Servers.Manager do
  @moduledoc """
  Facade for managing Hytale server instances.

  Provides a clean API for CRUD operations on server configs and
  starting/stopping/querying running server instances.
  """

  alias Hytalix.Repo
  alias Hytalix.Servers.{Downloader, Instance, Server}
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
  Deletes a server configuration and its files.
  """
  def delete_server(%Server{} = server) do
    # Stop the server if running
    stop_server(server.id)

    # Delete server files
    server_dir = default_download_dir(server.id)
    if File.exists?(server_dir), do: File.rm_rf!(server_dir)

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

  # ============================================================================
  # Server File Downloads
  # ============================================================================

  @doc """
  Starts downloading Hytale server files for a server.
  Returns {:ok, pid} on success.
  """
  def start_download(server_id, download_dir) do
    Downloader.start_download(server_id, download_dir)
  end

  @doc """
  Returns the default download directory for a server.
  """
  def default_download_dir(server_id) do
    Path.join([Application.app_dir(:hytalix, "priv"), "servers", "server_#{server_id}"])
  end

  @doc """
  Detects the Java path from common locations.
  """
  def detect_java_path do
    # Try common Java locations
    paths = [
      System.find_executable("java"),
      Path.expand("~/.local/share/mise/installs/java/openjdk-25.0.1/bin/java"),
      "/usr/bin/java",
      "/usr/lib/jvm/java-25-openjdk/bin/java"
    ]

    Enum.find(paths, fn
      nil -> false
      path -> File.exists?(path)
    end)
  end
end

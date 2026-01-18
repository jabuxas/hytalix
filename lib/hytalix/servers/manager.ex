defmodule Hytalix.Servers.Manager do
  @moduledoc "Facade for managing Hytale server instances."

  alias Hytalix.Repo
  alias Hytalix.Servers.{Downloader, Instance, Server}
  import Ecto.Query

  @supervisor Hytalix.ServerSupervisor
  @registry Hytalix.ServerRegistry

  def list_all_servers, do: Repo.all(Server)

  def get_server!(id), do: Repo.get!(Server, id)

  def get_server(id), do: Repo.get(Server, id)

  def create_server(attrs \\ %{}) do
    %Server{}
    |> Server.changeset(attrs)
    |> Repo.insert()
  end

  def update_server(%Server{} = server, attrs) do
    server
    |> Server.changeset(attrs)
    |> Repo.update()
  end

  def delete_server(%Server{} = server) do
    stop_server(server.id)
    server_dir = default_download_dir(server.id)
    if File.exists?(server_dir), do: File.rm_rf!(server_dir)
    Repo.delete(server)
  end

  def change_server(%Server{} = server, attrs \\ %{}) do
    Server.changeset(server, attrs)
  end

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

  def start_download(server_id, download_dir) do
    Downloader.start_download(server_id, download_dir)
  end

  def default_download_dir(server_id) do
    base_dir = System.get_env("HYTALIX_DATA_DIR") || Application.app_dir(:hytalix, "priv")
    Path.join([base_dir, "servers", "server_#{server_id}"])
  end

  def detect_java_path do
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

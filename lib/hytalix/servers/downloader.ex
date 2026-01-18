defmodule Hytalix.Servers.Downloader do
  @moduledoc """
  Handles downloading Hytale server files using the official hytale-downloader.
  Manages OAuth device flow authentication and file extraction.
  """
  use GenServer
  require Logger

  @downloader_url "https://downloader.hytale.com/hytale-downloader.zip"
  @downloader_binary "hytale-downloader-linux-amd64"

  defstruct [:server_id, :download_dir, :port, :status, :auth_url, :progress]

  # Client API

  def start_download(server_id, download_dir) do
    GenServer.start(__MODULE__, %{server_id: server_id, download_dir: download_dir})
  end

  def get_status(pid) do
    GenServer.call(pid, :get_status)
  end

  # Server callbacks

  @impl true
  def init(%{server_id: server_id, download_dir: download_dir}) do
    state = %__MODULE__{
      server_id: server_id,
      download_dir: download_dir,
      status: :initializing,
      progress: nil,
      auth_url: nil
    }

    send(self(), :start)
    {:ok, state}
  end

  @impl true
  def handle_info(:start, state) do
    # Ensure download directory exists
    File.mkdir_p!(state.download_dir)
    broadcast(state.server_id, {:download_status, :downloading_tool})

    # Download the hytale-downloader tool asynchronously
    parent = self()

    Task.start(fn ->
      result = ensure_downloader(state.download_dir)
      send(parent, {:downloader_ready, result})
    end)

    {:noreply, %{state | status: :downloading_tool}}
  end

  @impl true
  def handle_info({:downloader_ready, {:ok, downloader_path}}, state) do
    Logger.info("[Downloader] Starting hytale-downloader")
    broadcast(state.server_id, {:download_status, :starting})
    port = start_downloader(downloader_path, state.download_dir)
    {:noreply, %{state | port: port, status: :downloading}}
  end

  @impl true
  def handle_info({:downloader_ready, {:error, reason}}, state) do
    broadcast(state.server_id, {:download_error, reason})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    output = to_string(data)
    Logger.debug("[Downloader] #{output}")

    state = parse_output(output, state)
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:exit_status, 0}}, %{port: port} = state) do
    Logger.info("[Downloader] Download completed successfully")
    broadcast(state.server_id, {:download_status, :extracting})

    case extract_files(state.download_dir) do
      {:ok, paths} ->
        broadcast(state.server_id, {:download_complete, paths})

      {:error, reason} ->
        Logger.error("[Downloader] Extraction failed: #{reason}")
        broadcast(state.server_id, {:download_error, "Extraction failed: #{reason}"})
    end

    {:stop, :normal, state}
  end

  @impl true
  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    Logger.error("[Downloader] Download failed with exit code #{code}")
    broadcast(state.server_id, {:download_error, "Download failed with exit code #{code}"})
    {:stop, :normal, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, %{status: state.status, progress: state.progress, auth_url: state.auth_url}, state}
  end

  # Private functions

  defp ensure_downloader(download_dir) do
    downloader_path = Path.join(download_dir, @downloader_binary)

    if File.exists?(downloader_path) do
      {:ok, downloader_path}
    else
      download_and_extract_downloader(download_dir)
    end
  end

  defp download_and_extract_downloader(download_dir) do
    zip_path = Path.join(download_dir, "hytale-downloader.zip")

    Logger.info("[Downloader] Downloading hytale-downloader from #{@downloader_url}")

    case Req.get(@downloader_url, into: File.stream!(zip_path)) do
      {:ok, %{status: 200}} ->
        Logger.info("[Downloader] Extracting hytale-downloader")

        case :zip.unzip(String.to_charlist(zip_path), [{:cwd, String.to_charlist(download_dir)}]) do
          {:ok, _} ->
            downloader_path = Path.join(download_dir, @downloader_binary)
            File.chmod!(downloader_path, 0o755)
            {:ok, downloader_path}

          {:error, reason} ->
            {:error, "Failed to extract downloader: #{inspect(reason)}"}
        end

      {:ok, %{status: status}} ->
        {:error, "Failed to download: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Download failed: #{inspect(reason)}"}
    end
  end

  defp start_downloader(downloader_path, download_dir) do
    Port.open({:spawn_executable, downloader_path}, [
      :binary,
      :exit_status,
      :stderr_to_stdout,
      {:cd, download_dir},
      {:args, []}
    ])
  end

  defp parse_output(output, state) do
    cond do
      # OAuth device flow URL
      String.contains?(output, "oauth.accounts.hytale.com") ->
        case Regex.run(~r{(https://oauth\.accounts\.hytale\.com/[^\s]+)}, output) do
          [_, url] ->
            Logger.info("[Downloader] Auth URL: #{url}")
            broadcast(state.server_id, {:auth_required, url})
            %{state | auth_url: url, status: :awaiting_auth}

          _ ->
            state
        end

      # Download progress
      String.contains?(output, "%") ->
        case Regex.run(~r{(\d+\.?\d*)%}, output) do
          [_, percent] ->
            progress = String.to_float(percent)
            broadcast(state.server_id, {:download_progress, progress})
            %{state | progress: progress, status: :downloading}

          _ ->
            state
        end

      # Auth successful
      String.contains?(output, "successfully downloaded") ->
        broadcast(state.server_id, {:download_status, :completed})
        %{state | status: :completed}

      true ->
        state
    end
  end

  defp extract_files(download_dir) do
    # Find the downloaded zip file (e.g., 2026.01.17-4b0f30090.zip)
    case File.ls!(download_dir) |> Enum.find(&String.match?(&1, ~r/^\d{4}\.\d{2}\.\d{2}.*\.zip$/)) do
      nil ->
        {:error, "No game archive found"}

      zip_name ->
        zip_path = Path.join(download_dir, zip_name)
        Logger.info("[Downloader] Extracting #{zip_path}")

        # Use system unzip for large files (Erlang :zip can't handle 1.4GB in memory)
        case System.cmd("unzip", ["-o", "-q", zip_path, "-d", download_dir], stderr_to_stdout: true) do
          {_, 0} ->
            server_jar = Path.join([download_dir, "Server", "HytaleServer.jar"])
            assets_zip = Path.join(download_dir, "Assets.zip")

            if File.exists?(server_jar) and File.exists?(assets_zip) do
              {:ok, %{server_jar_path: server_jar, assets_path: assets_zip}}
            else
              {:error, "Expected files not found after extraction"}
            end

          {output, code} ->
            {:error, "unzip failed (code #{code}): #{output}"}
        end
    end
  end

  defp broadcast(server_id, message) do
    Phoenix.PubSub.broadcast(Hytalix.PubSub, "download:#{server_id}", message)
  end
end

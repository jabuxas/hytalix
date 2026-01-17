defmodule HytalixWeb.DashboardLive do
  use HytalixWeb, :live_view

  alias Hytalix.Servers.{Manager, Server}

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Hytalix.PubSub, "servers")

    servers = Manager.list_all_servers()
    running_ids = Manager.list_running_servers() |> MapSet.new()

    socket =
      socket
      |> assign(running_ids: running_ids, servers_empty?: servers == [])
      |> stream(:servers, servers)
      |> assign(show_modal: false, form: nil, editing_server: nil)

    {:ok, socket}
  end

  def handle_info({:server_started, id}, socket) do
    running_ids = MapSet.put(socket.assigns.running_ids, id)

    socket =
      socket
      |> assign(running_ids: running_ids)
      |> stream_insert(:servers, Manager.get_server!(id))

    {:noreply, socket}
  end

  def handle_info({:server_stopped, id}, socket) do
    running_ids = MapSet.delete(socket.assigns.running_ids, id)

    socket =
      socket
      |> assign(running_ids: running_ids)
      |> stream_insert(:servers, Manager.get_server!(id))

    {:noreply, socket}
  end

  def handle_event("new_server", _params, socket) do
    changeset = Manager.change_server(%Server{})
    {:noreply, assign(socket, show_modal: true, form: to_form(changeset), editing_server: nil)}
  end

  def handle_event("edit_server", %{"id" => id}, socket) do
    server = Manager.get_server!(String.to_integer(id))
    changeset = Manager.change_server(server)
    {:noreply, assign(socket, show_modal: true, form: to_form(changeset), editing_server: server)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false, form: nil, editing_server: nil)}
  end

  def handle_event("validate", %{"server" => params}, socket) do
    server = socket.assigns.editing_server || %Server{}

    changeset =
      server
      |> Manager.change_server(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save_server", %{"server" => params}, socket) do
    case socket.assigns.editing_server do
      nil ->
        # Creating new server
        case Manager.create_server(params) do
          {:ok, server} ->
            socket =
              socket
              |> stream_insert(:servers, server)
              |> assign(show_modal: false, form: nil, editing_server: nil, servers_empty?: false)
              |> put_flash(:info, "Server '#{server.name}' created successfully")

            {:noreply, socket}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end

      server ->
        # Updating existing server
        case Manager.update_server(server, params) do
          {:ok, updated_server} ->
            socket =
              socket
              |> stream_insert(:servers, updated_server)
              |> assign(show_modal: false, form: nil, editing_server: nil)
              |> put_flash(:info, "Server '#{updated_server.name}' updated successfully")

            {:noreply, socket}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end

  def handle_event("start_server", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case Manager.start_server(id) do
      {:ok, _pid} ->
        {:noreply, put_flash(socket, :info, "Server starting...")}

      {:error, {:already_started, _}} ->
        {:noreply, put_flash(socket, :error, "Server is already running")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start: #{inspect(reason)}")}
    end
  end

  def handle_event("stop_server", %{"id" => id}, socket) do
    Manager.stop_server(String.to_integer(id))
    {:noreply, socket}
  end

  def handle_event("delete_server", %{"id" => id}, socket) do
    server = Manager.get_server!(String.to_integer(id))

    if MapSet.member?(socket.assigns.running_ids, server.id) do
      {:noreply, put_flash(socket, :error, "Stop the server before deleting")}
    else
      case Manager.delete_server(server) do
        {:ok, _} ->
          {:noreply, stream_delete(socket, :servers, server)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete server")}
      end
    end
  end

  defp running?(assigns, server) do
    MapSet.member?(assigns.running_ids, server.id)
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-extrabold tracking-tight">Server Management</h1>
        <button phx-click="new_server" class="btn btn-primary">
          <.icon name="hero-plus-solid" class="size-4" /> New Server
        </button>
      </div>

      <%= if @servers_empty? do %>
        <div class="text-center py-20 border-2 border-dashed border-base-300 rounded-box">
          <p class="text-base-content/50 italic">
            No servers configured. Click "New Server" to create one.
          </p>
        </div>
      <% end %>

      <div
        id="servers"
        phx-update="stream"
        class={["grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6", @servers_empty? && "hidden"]}
      >
        <div
          :for={{dom_id, server} <- @streams.servers}
          id={dom_id}
          class="card bg-base-200 border border-base-300 shadow-sm hover:shadow-md transition-shadow"
        >
          <div class="card-body">
            <div class="flex justify-between items-start">
              <div>
                <h2 class="card-title text-primary">{server.name}</h2>
                <p class="text-xs opacity-60 font-mono">Port {server.port}</p>
                <div class="flex items-center gap-2 mt-2">
                  <%= if running?(assigns, server) do %>
                    <span class="relative flex h-2 w-2">
                      <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-success opacity-75">
                      </span>
                      <span class="relative inline-flex rounded-full h-2 w-2 bg-success"></span>
                    </span>
                    <span class="text-xs font-mono opacity-60 uppercase">Online</span>
                  <% else %>
                    <span class="relative flex h-2 w-2">
                      <span class="relative inline-flex rounded-full h-2 w-2 bg-base-content/30">
                      </span>
                    </span>
                    <span class="text-xs font-mono opacity-60 uppercase">Offline</span>
                  <% end %>
                </div>
              </div>
              <button
                phx-click="edit_server"
                phx-value-id={server.id}
                class="btn btn-sm btn-ghost btn-circle"
                title="Edit server"
              >
                <.icon name="hero-pencil-square" class="size-4" />
              </button>
            </div>

            <div class="text-xs opacity-50 mt-2">
              <p>Memory: {server.memory_min_mb}MB - {server.memory_max_mb}MB</p>
            </div>

            <div class="card-actions justify-end mt-4">
              <%= if running?(assigns, server) do %>
                <.link navigate={~p"/server/#{server.id}"} class="btn btn-sm btn-ghost">
                  Console
                </.link>
                <button
                  phx-click="stop_server"
                  phx-value-id={server.id}
                  class="btn btn-sm btn-error btn-soft"
                >
                  Stop
                </button>
              <% else %>
                <button
                  phx-click="delete_server"
                  phx-value-id={server.id}
                  data-confirm="Are you sure you want to delete this server?"
                  class="btn btn-sm btn-ghost text-error"
                >
                  Delete
                </button>
                <button
                  phx-click="start_server"
                  phx-value-id={server.id}
                  class="btn btn-sm btn-success"
                >
                  Start
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%= if @show_modal do %>
        <.modal id="server-modal" show on_cancel={JS.push("close_modal")}>
          <h3 class="text-lg font-bold mb-4">
            <%= if @editing_server, do: "Edit Server", else: "Create New Server" %>
          </h3>
          <.form
            for={@form}
            id="server-form"
            phx-change="validate"
            phx-submit="save_server"
            class="space-y-4"
          >
            <div class="grid grid-cols-2 gap-4">
              <.input field={@form[:name]} label="Server Name" placeholder="My Hytale Server" />
              <.input field={@form[:port]} label="Port" type="number" />
            </div>

            <.input
              field={@form[:java_path]}
              label="Java Path"
              placeholder="/usr/bin/java or full path to java binary"
            />

            <.input
              field={@form[:server_jar_path]}
              label="Server JAR Path"
              placeholder="/path/to/HytaleServer.jar"
            />
            <.input field={@form[:assets_path]} label="Assets Path" placeholder="/path/to/Assets.zip" />

            <div class="grid grid-cols-2 gap-4">
              <.input field={@form[:memory_min_mb]} label="Min Memory (MB)" type="number" />
              <.input field={@form[:memory_max_mb]} label="Max Memory (MB)" type="number" />
            </div>

            <div class="grid grid-cols-2 gap-4">
              <.input
                field={@form[:auth_mode]}
                label="Auth Mode"
                type="select"
                options={[{"Authenticated", "authenticated"}, {"Offline", "offline"}]}
              />
              <.input field={@form[:view_distance]} label="View Distance (chunks)" type="number" />
            </div>

            <div class="flex gap-4">
              <.input field={@form[:use_aot_cache]} label="Use AOT Cache" type="checkbox" />
              <.input field={@form[:disable_sentry]} label="Disable Sentry" type="checkbox" />
              <.input field={@form[:auto_start]} label="Auto-start on boot" type="checkbox" />
            </div>

            <div class="divider">Backups</div>

            <.input field={@form[:backup_enabled]} label="Enable Backups" type="checkbox" />
            <div class="grid grid-cols-2 gap-4">
              <.input
                field={@form[:backup_dir]}
                label="Backup Directory"
                placeholder="/path/to/backups"
              />
              <.input
                field={@form[:backup_frequency_minutes]}
                label="Frequency (minutes)"
                type="number"
              />
            </div>

            <div class="modal-action">
              <button type="button" phx-click="close_modal" class="btn btn-ghost">Cancel</button>
              <button type="submit" class="btn btn-primary">
                <%= if @editing_server, do: "Save Changes", else: "Create Server" %>
              </button>
            </div>
          </.form>
        </.modal>
      <% end %>
    </Layouts.app>
    """
  end
end

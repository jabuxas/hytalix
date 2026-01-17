defmodule Hytalix.Servers.Server do
  @moduledoc """
  Schema for Hytale server configurations.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @auth_modes ~w(authenticated offline)

  schema "servers" do
    field :name, :string
    field :port, :integer, default: 5520
    field :bind_address, :string, default: "0.0.0.0"

    # Java settings
    field :java_path, :string, default: "java"
    field :memory_min_mb, :integer, default: 1024
    field :memory_max_mb, :integer, default: 4096

    # Paths
    field :server_jar_path, :string
    field :assets_path, :string

    # Server options
    field :auth_mode, :string, default: "authenticated"
    field :view_distance, :integer, default: 12
    field :use_aot_cache, :boolean, default: true
    field :disable_sentry, :boolean, default: false

    # Backup settings
    field :backup_enabled, :boolean, default: false
    field :backup_dir, :string
    field :backup_frequency_minutes, :integer, default: 30

    # Auto-start on panel boot
    field :auto_start, :boolean, default: false

    timestamps()
  end

  @required_fields ~w(name port server_jar_path assets_path)a
  @optional_fields ~w(
    bind_address java_path memory_min_mb memory_max_mb auth_mode view_distance
    use_aot_cache disable_sentry backup_enabled backup_dir
    backup_frequency_minutes auto_start
  )a

  def changeset(server, attrs) do
    server
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:auth_mode, @auth_modes)
    |> validate_number(:port, greater_than: 0, less_than: 65536)
    |> validate_number(:memory_min_mb, greater_than_or_equal_to: 512)
    |> validate_number(:memory_max_mb, greater_than_or_equal_to: 1024)
    |> validate_number(:view_distance, greater_than: 0, less_than_or_equal_to: 32)
    |> validate_number(:backup_frequency_minutes, greater_than: 0)
    |> validate_memory_settings()
    |> unique_constraint(:port)
    |> unique_constraint(:name)
  end

  defp validate_memory_settings(changeset) do
    min = get_field(changeset, :memory_min_mb)
    max = get_field(changeset, :memory_max_mb)

    if min && max && min > max do
      add_error(changeset, :memory_min_mb, "must be less than or equal to max memory")
    else
      changeset
    end
  end

  @doc """
  Builds the java command to start this server.
  """
  def build_command(%__MODULE__{} = server) do
    java_args = [
      "-Xms#{server.memory_min_mb}m",
      "-Xmx#{server.memory_max_mb}m"
    ]

    # AOT cache improves startup but must match Java version
    java_args =
      if server.use_aot_cache do
        aot_path = Path.join(Path.dirname(server.server_jar_path), "HytaleServer.aot")

        if File.exists?(aot_path) do
          java_args ++ ["-XX:AOTCache=#{aot_path}"]
        else
          java_args
        end
      else
        java_args
      end

    jar_args = [
      "-jar",
      server.server_jar_path,
      "--assets",
      server.assets_path,
      "--bind",
      "#{server.bind_address}:#{server.port}",
      "--auth-mode",
      server.auth_mode
    ]

    # Note: --view-distance may not be supported in all server versions
    # Removed from command generation for now

    jar_args =
      if server.disable_sentry do
        jar_args ++ ["--disable-sentry"]
      else
        jar_args
      end

    jar_args =
      if server.backup_enabled do
        backup_args = [
          "--backup",
          "--backup-frequency",
          to_string(server.backup_frequency_minutes)
        ]

        backup_args =
          if server.backup_dir do
            backup_args ++ ["--backup-dir", server.backup_dir]
          else
            backup_args
          end

        jar_args ++ backup_args
      else
        jar_args
      end

    java_bin = server.java_path || "java"
    Enum.join([java_bin] ++ java_args ++ jar_args, " ")
  end
end

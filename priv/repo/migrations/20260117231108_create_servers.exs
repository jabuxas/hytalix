defmodule Hytalix.Repo.Migrations.CreateServers do
  use Ecto.Migration

  def change do
    create table(:servers) do
      add :name, :string, null: false
      add :port, :integer, null: false, default: 5520
      add :bind_address, :string, null: false, default: "0.0.0.0"

      # Java memory settings
      add :memory_min_mb, :integer, null: false, default: 1024
      add :memory_max_mb, :integer, null: false, default: 4096

      # Paths
      add :server_jar_path, :string, null: false
      add :assets_path, :string, null: false

      # Server options
      add :auth_mode, :string, null: false, default: "authenticated"
      add :view_distance, :integer, default: 12
      add :use_aot_cache, :boolean, default: true
      add :disable_sentry, :boolean, default: false

      # Backup settings
      add :backup_enabled, :boolean, default: false
      add :backup_dir, :string
      add :backup_frequency_minutes, :integer, default: 30

      # Status tracking
      add :auto_start, :boolean, default: false

      timestamps()
    end

    create unique_index(:servers, [:port])
    create unique_index(:servers, [:name])
  end
end

defmodule Hytalix.Repo.Migrations.MakePathsOptional do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      modify :server_jar_path, :string, null: true
      modify :assets_path, :string, null: true
    end
  end
end

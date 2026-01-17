defmodule Hytalix.Repo.Migrations.AddJavaPathToServers do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      add :java_path, :string, null: false, default: "java"
    end
  end
end

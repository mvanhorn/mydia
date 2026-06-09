defmodule Mydia.Repo.Migrations.CreatePathMappingConfigs do
  use Ecto.Migration

  def change do
    # Remote→local path prefix mappings. Text columns + binary_id keep this
    # byte-identical across SQLite and Postgres (both CI targets).
    create table(:path_mapping_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :remote_prefix, :text, null: false
      add :local_prefix, :text, null: false
      add :updated_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:path_mapping_configs, [:remote_prefix])
  end
end

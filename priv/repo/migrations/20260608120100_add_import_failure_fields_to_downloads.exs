defmodule Mydia.Repo.Migrations.AddImportFailureFieldsToDownloads do
  use Ecto.Migration

  def change do
    alter table(:downloads) do
      # Structured failure classification + the client-reported path, so the
      # Issues tab can detect a path-mapping mismatch and compute a suggestion
      # without parsing the human-readable import_last_error string.
      add :import_failure_reason, :string
      add :import_reported_path, :text
    end
  end
end

defmodule Mydia.Settings.PathMappingConfig do
  @moduledoc """
  Schema for download-path mappings: a remote→local prefix rewrite applied to
  paths reported by download clients before Mydia resolves them on disk.

  Self-hosted setups commonly run the download client in a separate container
  with different volume mounts, so a path the client reports as complete (e.g.
  `/downloads/complete/<release>`) does not exist inside Mydia's filesystem view.
  A mapping translates the reported remote prefix to the local prefix Mydia can
  see (e.g. `/downloads/complete` → `/data/torrents/complete`).

  Mappings layer like the other service configs: defined via
  `PATH_MAPPING_<N>_REMOTE` / `PATH_MAPPING_<N>_LOCAL` env vars or in the DB, with
  a DB row shadowing an env entry that shares the same `remote_prefix`. The
  longest matching prefix wins at rewrite time, so there is no ordering column.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary(),
          remote_prefix: String.t() | nil,
          local_prefix: String.t() | nil,
          updated_by: Mydia.Accounts.User.t() | nil | Ecto.Association.NotLoaded.t(),
          updated_by_id: binary() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "path_mapping_configs" do
    field :remote_prefix, :string
    field :local_prefix, :string

    belongs_to :updated_by, Mydia.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a path mapping.

  Both prefixes are normalized (trailing slash stripped) before validation so
  `/downloads/` and `/downloads` collapse to the same unique key. Both must be
  absolute and free of `..` segments — `rewrite/1` hands its result straight to a
  recursive file lister, so a relative or traversing prefix could redirect the
  importer outside the intended tree. A `remote_prefix` of `/` or a single path
  component is rejected because it would match nearly every reported path in the
  fan-out re-enqueue.
  """
  def changeset(path_mapping_config, attrs) do
    path_mapping_config
    |> cast(attrs, [:remote_prefix, :local_prefix, :updated_by_id])
    |> update_change(:remote_prefix, &normalize_prefix/1)
    |> update_change(:local_prefix, &normalize_prefix/1)
    |> validate_required([:remote_prefix, :local_prefix])
    |> validate_absolute(:remote_prefix)
    |> validate_absolute(:local_prefix)
    |> validate_no_traversal(:remote_prefix)
    |> validate_no_traversal(:local_prefix)
    |> validate_remote_prefix_specific()
    |> validate_distinct_prefixes()
    |> unique_constraint(:remote_prefix)
  end

  @doc """
  Normalizes a path prefix for storage and comparison: trims surrounding
  whitespace and strips a trailing slash (except for the root `/`).
  """
  @spec normalize_prefix(String.t() | nil) :: String.t() | nil
  def normalize_prefix(nil), do: nil

  def normalize_prefix(value) when is_binary(value) do
    trimmed = String.trim(value)

    case trimmed do
      "/" -> "/"
      other -> String.replace_trailing(other, "/", "")
    end
  end

  defp validate_absolute(changeset, field) do
    case get_field(changeset, field) do
      "/" <> _ -> changeset
      nil -> changeset
      _ -> add_error(changeset, field, "must be an absolute path (start with /)")
    end
  end

  defp validate_no_traversal(changeset, field) do
    case get_field(changeset, field) do
      value when is_binary(value) ->
        if ".." in Path.split(value) do
          add_error(changeset, field, "must not contain '..' segments")
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  # A remote_prefix that is "/" or a single path component (e.g. "/downloads")
  # is allowed only when it has at least two components, because the apply-and-
  # retry fan-out re-enqueues every download whose reported path shares the
  # prefix — too broad a prefix would sweep in unrelated downloads.
  defp validate_remote_prefix_specific(changeset) do
    case get_field(changeset, :remote_prefix) do
      value when is_binary(value) ->
        # Path.split("/downloads/complete") => ["/", "downloads", "complete"]
        if length(Path.split(value)) < 3 do
          add_error(
            changeset,
            :remote_prefix,
            "must be at least two path segments deep (e.g. /downloads/complete)"
          )
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp validate_distinct_prefixes(changeset) do
    remote = get_field(changeset, :remote_prefix)
    local = get_field(changeset, :local_prefix)

    if not is_nil(remote) and remote == local do
      add_error(changeset, :local_prefix, "must differ from the remote prefix")
    else
      changeset
    end
  end
end

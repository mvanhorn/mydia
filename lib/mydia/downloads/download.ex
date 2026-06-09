defmodule Mydia.Downloads.Download do
  @moduledoc """
  Schema for download queue items.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary(),
          indexer: String.t() | nil,
          title: String.t() | nil,
          download_url: String.t() | nil,
          download_client: String.t() | nil,
          download_client_id: String.t() | nil,
          completed_at: DateTime.t() | nil,
          error_message: String.t() | nil,
          metadata: map() | nil,
          match_status: String.t() | nil,
          imported_at: DateTime.t() | nil,
          import_retry_count: integer(),
          import_last_error: String.t() | nil,
          import_failure_reason: String.t() | nil,
          import_reported_path: String.t() | nil,
          import_next_retry_at: DateTime.t() | nil,
          import_failed_at: DateTime.t() | nil,
          last_progress_at: DateTime.t() | nil,
          last_known_bytes: integer(),
          bytes_pulled: integer() | nil,
          media_item: Mydia.Media.MediaItem.t() | Ecto.Association.NotLoaded.t(),
          episode: Mydia.Media.Episode.t() | nil | Ecto.Association.NotLoaded.t(),
          library_path: Mydia.Settings.LibraryPath.t() | nil | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "downloads" do
    field :indexer, :string
    field :title, :string
    field :download_url, :string
    field :download_client, :string
    field :download_client_id, :string
    field :completed_at, :utc_datetime
    field :error_message, :string
    field :metadata, Mydia.Settings.JsonMapType
    field :match_status, :string

    # Import tracking fields
    field :imported_at, :utc_datetime
    field :import_retry_count, :integer, default: 0
    field :import_last_error, :string
    # Structured failure classification (e.g. "path_mapping_mismatch") so the
    # Issues tab can filter without parsing the human `import_last_error` string.
    field :import_failure_reason, :string
    # The client-reported path Mydia could not see, persisted so the Issues tab
    # can compute a path-mapping suggestion after the job has finished.
    field :import_reported_path, :string
    field :import_next_retry_at, :utc_datetime
    field :import_failed_at, :utc_datetime

    # Stall-detection / progress tracking fields. `last_progress_at` is the
    # timestamp of the last observed bytes-downloaded increment; `last_known_bytes`
    # is the byte count at that moment. Used by the stall-detection circuit
    # breaker to avoid polling stuck downloads forever.
    field :last_progress_at, :utc_datetime_usec
    field :last_known_bytes, :integer, default: 0

    # Bytes streamed locally into staging by the debrid Fetcher (or any future
    # adapter that performs a separate post-completion local pull). Updated
    # atomically every 8 MB during streaming so the Range-resume recovery path
    # in `Fetcher.init/1` knows where to resume after a crash. Nil for adapters
    # that don't perform a local pull.
    field :bytes_pulled, :integer

    belongs_to :media_item, Mydia.Media.MediaItem
    belongs_to :episode, Mydia.Media.Episode

    # For specialized library downloads (music, books, adult) that don't have
    # a media_item, this field indicates which library to import files to
    belongs_to :library_path, Mydia.Settings.LibraryPath

    timestamps(type: :utc_datetime, updated_at: :updated_at)
  end

  @doc """
  Changeset for creating or updating a download.
  """
  def changeset(download, attrs) do
    download
    |> cast(attrs, [
      :media_item_id,
      :episode_id,
      :library_path_id,
      :indexer,
      :title,
      :download_url,
      :download_client,
      :download_client_id,
      :completed_at,
      :error_message,
      :metadata,
      :match_status,
      :imported_at,
      :import_retry_count,
      :import_last_error,
      :import_failure_reason,
      :import_reported_path,
      :import_next_retry_at,
      :import_failed_at,
      :last_progress_at,
      :last_known_bytes,
      :bytes_pulled
    ])
    |> validate_required([:title])
    |> validate_inclusion(:match_status, ["unmatched", "unresolved_files", "partial_pack"])
    |> foreign_key_constraint(:media_item_id)
    |> foreign_key_constraint(:episode_id)
    |> foreign_key_constraint(:library_path_id)
    |> unique_constraint([:download_client, :download_client_id],
      message: "download already exists for this torrent"
    )
  end
end

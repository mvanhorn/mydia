defmodule Mydia.Library.PathMapping do
  @moduledoc """
  Applies configured remote→local prefix rewrites to paths reported by download
  clients, and classifies whether a missing path is a container mount-mismatch
  rather than a genuinely missing file.

  See `Mydia.Settings.PathMappingConfig` for the configuration model.
  """

  alias Mydia.Settings

  @doc """
  Rewrites `path` through the longest matching configured remote prefix.

  Returns the path unchanged when no prefix matches. The rewritten result is
  canonicalized; if the rewrite would escape its local prefix (via `..`), the
  original path is returned unchanged so the importer fails as a mismatch rather
  than reading an unintended directory.
  """
  @spec rewrite(String.t()) :: String.t()
  def rewrite(path) when is_binary(path) do
    case Enum.find(Settings.list_path_mapping_configs(), &under_prefix?(path, &1.remote_prefix)) do
      nil -> path
      mapping -> apply_mapping(path, mapping)
    end
  end

  def rewrite(path), do: path

  @doc """
  True when the reported path looks like a container volume mount-mismatch: its
  immediate parent directory is not visible inside Mydia's filesystem.

  A genuinely deleted leaf keeps a visible parent and returns `false`; the
  `/downloads` visible / `/downloads/complete` invisible layout returns `true`.
  """
  @spec mount_mismatch?(String.t()) :: boolean()
  def mount_mismatch?(path) when is_binary(path) do
    not File.exists?(Path.dirname(path))
  end

  def mount_mismatch?(_), do: false

  defp under_prefix?(path, prefix) when is_binary(prefix) do
    path == prefix or String.starts_with?(path, prefix <> "/")
  end

  defp under_prefix?(_path, _prefix), do: false

  defp apply_mapping(path, %{remote_prefix: remote, local_prefix: local}) do
    candidate =
      path
      |> String.replace_prefix(remote, local)
      |> Path.expand()

    # Defense in depth: the stored prefixes are validated to be absolute and
    # free of `..`, but the path tail comes from the download client. If the
    # canonicalized result escapes the local prefix, refuse the rewrite.
    if String.starts_with?(candidate, local) do
      candidate
    else
      path
    end
  end
end

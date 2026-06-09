defmodule Mydia.Settings.PathMappingConfigTest do
  use Mydia.DataCase, async: true

  alias Mydia.Settings.PathMappingConfig

  defp changeset(attrs), do: PathMappingConfig.changeset(%PathMappingConfig{}, attrs)

  describe "changeset/2" do
    test "is valid with absolute, distinct, multi-segment prefixes" do
      cs =
        changeset(%{
          remote_prefix: "/downloads/complete",
          local_prefix: "/data/torrents/complete"
        })

      assert cs.valid?
    end

    test "normalizes trailing slashes on both prefixes" do
      cs =
        changeset(%{
          remote_prefix: "/downloads/complete/",
          local_prefix: "/data/torrents/complete/"
        })

      assert cs.valid?
      assert get_change(cs, :remote_prefix) == "/downloads/complete"
      assert get_change(cs, :local_prefix) == "/data/torrents/complete"
    end

    test "requires both prefixes" do
      cs = changeset(%{remote_prefix: "/downloads/complete"})
      refute cs.valid?
      assert %{local_prefix: ["can't be blank"]} = errors_on(cs)
    end

    test "rejects identical remote and local prefixes" do
      cs = changeset(%{remote_prefix: "/data/complete", local_prefix: "/data/complete"})
      refute cs.valid?
      assert %{local_prefix: ["must differ from the remote prefix"]} = errors_on(cs)
    end

    test "rejects relative prefixes" do
      cs = changeset(%{remote_prefix: "relative/a/b", local_prefix: "/data/complete"})
      refute cs.valid?
      assert "must be an absolute path (start with /)" in errors_on(cs).remote_prefix
    end

    test "rejects prefixes containing .. segments" do
      cs = changeset(%{remote_prefix: "/downloads/complete", local_prefix: "/data/../etc"})
      refute cs.valid?
      assert %{local_prefix: ["must not contain '..' segments"]} = errors_on(cs)
    end

    test "rejects a remote_prefix shallower than two segments" do
      cs = changeset(%{remote_prefix: "/downloads", local_prefix: "/data/torrents/complete"})
      refute cs.valid?
      assert %{remote_prefix: [_]} = errors_on(cs)
    end

    test "rejects a root remote_prefix" do
      cs = changeset(%{remote_prefix: "/", local_prefix: "/data/torrents"})
      refute cs.valid?
    end

    test "enforces unique remote_prefix at insert" do
      attrs = %{remote_prefix: "/downloads/complete", local_prefix: "/data/torrents/complete"}
      assert {:ok, _} = Repo.insert(changeset(attrs))
      assert {:error, cs} = Repo.insert(changeset(%{attrs | local_prefix: "/data/other"}))
      assert %{remote_prefix: ["has already been taken"]} = errors_on(cs)
    end
  end
end

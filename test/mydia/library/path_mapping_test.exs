defmodule Mydia.Library.PathMappingTest do
  use Mydia.DataCase, async: true

  alias Mydia.Library.PathMapping
  alias Mydia.Settings

  defp mapping(remote, local) do
    {:ok, _} =
      Settings.create_path_mapping_config(%{remote_prefix: remote, local_prefix: local})

    :ok
  end

  describe "rewrite/1" do
    test "returns the path unchanged when no mapping matches" do
      assert PathMapping.rewrite("/downloads/complete/Show.S01E01") ==
               "/downloads/complete/Show.S01E01"
    end

    test "rewrites under the longest matching prefix" do
      mapping("/downloads/complete", "/data/torrents/complete")

      assert PathMapping.rewrite("/downloads/complete/Show.S01E01") ==
               "/data/torrents/complete/Show.S01E01"
    end

    test "prefers the more specific (longer) prefix when two could match" do
      mapping("/downloads/complete", "/data/general")
      mapping("/downloads/complete/anime", "/data/anime")

      assert PathMapping.rewrite("/downloads/complete/anime/Show") == "/data/anime/Show"
      assert PathMapping.rewrite("/downloads/complete/movies/Film") == "/data/general/movies/Film"
    end

    test "does not rewrite a path that only resembles the prefix without a boundary" do
      mapping("/downloads/complete", "/data/complete")
      # "/downloads/complete-other" is not under "/downloads/complete/"
      assert PathMapping.rewrite("/downloads/complete-other/x") == "/downloads/complete-other/x"
    end

    test "does not rewrite when path expansion escapes into a sibling local prefix" do
      mapping("/downloads/complete", "/data/a")

      assert PathMapping.rewrite("/downloads/complete/../ab/file.mkv") ==
               "/downloads/complete/../ab/file.mkv"
    end
  end

  describe "mount_mismatch?/1" do
    setup do
      tmp = Path.join(System.tmp_dir!(), "pm_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf(tmp) end)
      {:ok, tmp: tmp}
    end

    test "false when the immediate parent is visible (deleted leaf)", %{tmp: tmp} do
      # parent exists, leaf does not -> a genuinely missing file, not a mismatch
      refute PathMapping.mount_mismatch?(Path.join(tmp, "missing-release"))
    end

    test "true when the immediate parent is not visible (mount mismatch)", %{tmp: tmp} do
      # neither the leaf nor its parent exist inside Mydia's view
      path = Path.join([tmp, "unmounted", "complete", "Show.S01E01"])
      assert PathMapping.mount_mismatch?(path)
    end
  end
end

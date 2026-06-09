defmodule Mydia.Library.PathMappingSuggestionTest do
  use ExUnit.Case, async: true

  alias Mydia.Library.PathMapping

  setup do
    tmp = Path.join(System.tmp_dir!(), "pms_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(tmp) end)
    {:ok, tmp: tmp}
  end

  test "suggests a single mapping when exactly one match is found (AE1)", %{tmp: tmp} do
    root = Path.join(tmp, "data")
    File.mkdir_p!(Path.join([root, "torrents", "complete", "Severance.S02E10"]))

    assert {:ok, %{remote_prefix: "/downloads/complete", local_prefix: local}} =
             PathMapping.suggest("/downloads/complete/Severance.S02E10", [root])

    assert local == Path.join([root, "torrents", "complete"])
  end

  test "abstains when the basename matches under two roots (AE3)", %{tmp: tmp} do
    root_a = Path.join(tmp, "a")
    root_b = Path.join(tmp, "b")
    File.mkdir_p!(Path.join([root_a, "complete", "Show.S01E01"]))
    File.mkdir_p!(Path.join([root_b, "anime", "Show.S01E01"]))

    assert PathMapping.suggest("/downloads/complete/Show.S01E01", [root_a, root_b]) == :none
  end

  test "abstains when no match is found", %{tmp: tmp} do
    root = Path.join(tmp, "data")
    File.mkdir_p!(Path.join(root, "unrelated"))

    assert PathMapping.suggest("/downloads/complete/Missing.S01E01", [root]) == :none
  end

  test "derives prefixes correctly when the local dir nests deeper than the remote", %{tmp: tmp} do
    root = Path.join(tmp, "data")
    File.mkdir_p!(Path.join([root, "media", "tv", "downloads", "Release"]))

    assert {:ok, %{remote_prefix: "/dl", local_prefix: local}} =
             PathMapping.suggest("/dl/Release", [root])

    assert local == Path.join([root, "media", "tv", "downloads"])
  end
end

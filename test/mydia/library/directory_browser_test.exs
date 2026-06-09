defmodule Mydia.Library.DirectoryBrowserTest do
  use ExUnit.Case, async: true

  alias Mydia.Library.DirectoryBrowser

  setup do
    base = Path.join(System.tmp_dir!(), "dir_browser_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(base, "movies"))
    File.mkdir_p!(Path.join(base, "music"))
    File.mkdir_p!(Path.join(base, "shows"))
    File.write!(Path.join(base, "readme.txt"), "not a dir")

    on_exit(fn -> File.rm_rf!(base) end)

    {:ok, base: base}
  end

  describe "list_subdirectories/1" do
    test "returns only immediate subdirectories, never files", %{base: base} do
      result = DirectoryBrowser.list_subdirectories(base)

      assert Enum.sort(result) == [
               Path.join(base, "movies"),
               Path.join(base, "music"),
               Path.join(base, "shows")
             ]

      refute Path.join(base, "readme.txt") in result
    end

    test "returns [] for a missing path" do
      assert DirectoryBrowser.list_subdirectories("/no/such/path/at/all") == []
    end

    test "returns [] for a file rather than a directory", %{base: base} do
      assert DirectoryBrowser.list_subdirectories(Path.join(base, "readme.txt")) == []
    end
  end

  describe "suggest/1" do
    test "lists children when input ends in a slash", %{base: base} do
      result = DirectoryBrowser.suggest(base <> "/")

      assert Path.join(base, "movies") in result
      assert Path.join(base, "music") in result
      assert Path.join(base, "shows") in result
    end

    test "filters by the partial leaf name", %{base: base} do
      result = DirectoryBrowser.suggest(Path.join(base, "mu"))

      assert result == [Path.join(base, "music")]
    end

    test "matches multiple directories sharing a prefix", %{base: base} do
      result = DirectoryBrowser.suggest(Path.join(base, "m"))

      assert Enum.sort(result) == [Path.join(base, "movies"), Path.join(base, "music")]
    end

    test "returns [] for a non-existent parent directory" do
      assert DirectoryBrowser.suggest("/no/such/path/mo") == []
    end

    test "handles nil gracefully" do
      assert is_list(DirectoryBrowser.suggest(nil))
    end

    test "non-absolute input does not crash" do
      assert is_list(DirectoryBrowser.suggest("relative/path"))
    end
  end
end

defmodule Mydia.Library.MountRootsTest do
  use ExUnit.Case, async: true

  alias Mydia.Library.MountRoots

  setup do
    tmp = Path.join(System.tmp_dir!(), "mr_test_#{System.unique_integer([:positive])}")
    data = Path.join(tmp, "data")
    File.mkdir_p!(data)
    on_exit(fn -> File.rm_rf(tmp) end)
    {:ok, tmp: tmp, data: data}
  end

  describe "parse_mounts/1" do
    test "parses mount point and fstype, unescaping octal spaces" do
      contents = """
      proc /proc proc rw,nosuid 0 0
      /dev/sda1 /data ext4 rw,relatime 0 0
      /dev/sdb1 /mnt/my\\040disk xfs rw 0 0
      """

      parsed = MountRoots.parse_mounts(contents)
      assert {"/proc", "proc"} in parsed
      assert {"/data", "ext4"} in parsed
      assert {"/mnt/my disk", "xfs"} in parsed
    end
  end

  describe "detect/1" do
    test "returns [] when the mounts file can't be read" do
      assert MountRoots.detect(mounts_path: "/no/such/mounts", library_paths: ["/data"]) == []
    end

    test "keeps data mounts, drops virtual and system mounts", %{data: data} do
      mounts_file = Path.join(data, "mounts")

      File.write!(mounts_file, """
      proc /proc proc rw 0 0
      tmpfs /tmp tmpfs rw 0 0
      /dev/sda1 #{data} ext4 rw 0 0
      """)

      roots = MountRoots.detect(mounts_path: mounts_file, library_paths: [data])
      assert data in roots
      refute "/proc" in roots
      refute "/tmp" in roots
    end

    test "excludes data mounts that share no top-level with a library path", %{data: data} do
      mounts_file = Path.join(data, "mounts")
      File.write!(mounts_file, "/dev/sda1 #{data} ext4 rw 0 0\n")

      # library on a different top-level segment than the mount
      assert MountRoots.detect(mounts_path: mounts_file, library_paths: ["/elsewhere/media"]) ==
               []
    end
  end
end

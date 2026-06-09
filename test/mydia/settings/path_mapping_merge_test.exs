defmodule Mydia.Settings.PathMappingMergeTest do
  # async: false — mutates process env (PATH_MAPPING_*) and the cached runtime
  # config, then restores both in on_exit.
  use ExUnit.Case, async: false

  alias Mydia.Config.Loader
  alias Mydia.Settings
  alias Mydia.Settings.RuntimeConfig, as: RC

  setup do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Mydia.Repo, shared: true)
    original_runtime = Application.get_env(:mydia, :runtime_config)

    existing =
      System.get_env()
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "PATH_MAPPING_") end)
      |> Enum.map(fn {k, _} -> k end)

    Enum.each(existing, &System.delete_env/1)

    on_exit(fn ->
      Enum.each(existing, &System.delete_env/1)

      System.get_env()
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "PATH_MAPPING_") end)
      |> Enum.each(fn {k, _} -> System.delete_env(k) end)

      if original_runtime do
        Application.put_env(:mydia, :runtime_config, original_runtime)
      else
        Application.delete_env(:mydia, :runtime_config)
      end

      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
    end)

    :ok
  end

  defp reload_with_env(vars) do
    Enum.each(vars, fn {k, v} -> System.put_env(k, v) end)
    {:ok, _} = Loader.reload(config_file: "nonexistent.yml")
    :ok
  end

  test "env mappings load through the schema and carry runtime provenance" do
    reload_with_env(%{
      "PATH_MAPPING_1_REMOTE" => "/downloads/complete",
      "PATH_MAPPING_1_LOCAL" => "/data/torrents/complete"
    })

    [mapping] = RC.get_runtime_path_mappings()
    assert mapping.remote_prefix == "/downloads/complete"
    assert mapping.local_prefix == "/data/torrents/complete"
    assert RC.runtime_config?(mapping)
  end

  test "env mapping is resolvable by its synthetic (normalized) id" do
    reload_with_env(%{
      # trailing slash in the env value must normalize so the id round-trips
      "PATH_MAPPING_1_REMOTE" => "/downloads/complete/",
      "PATH_MAPPING_1_LOCAL" => "/data/torrents/complete"
    })

    [mapping] = RC.get_runtime_path_mappings()
    resolved = Settings.get_path_mapping_config!(mapping.id)
    assert resolved.remote_prefix == "/downloads/complete"
  end

  test "a DB row shadows an env entry with the same remote_prefix" do
    reload_with_env(%{
      "PATH_MAPPING_1_REMOTE" => "/downloads/complete",
      "PATH_MAPPING_1_LOCAL" => "/env/local"
    })

    {:ok, _db} =
      Settings.create_path_mapping_config(%{
        remote_prefix: "/downloads/complete",
        local_prefix: "/db/local"
      })

    mappings = Settings.list_path_mapping_configs()
    matching = Enum.filter(mappings, &(&1.remote_prefix == "/downloads/complete"))

    assert length(matching) == 1
    assert hd(matching).local_prefix == "/db/local"
    refute RC.runtime_config?(hd(matching))
  end

  test "merged list is sorted longest-prefix-first" do
    {:ok, _} =
      Settings.create_path_mapping_config(%{
        remote_prefix: "/downloads/complete",
        local_prefix: "/data/a"
      })

    {:ok, _} =
      Settings.create_path_mapping_config(%{
        remote_prefix: "/downloads/complete/tv/anime",
        local_prefix: "/data/b"
      })

    prefixes = Settings.list_path_mapping_configs() |> Enum.map(& &1.remote_prefix)
    assert prefixes == ["/downloads/complete/tv/anime", "/downloads/complete"]
  end

  test "create refreshes the runtime config so a new mapping is visible immediately" do
    {:ok, _} =
      Settings.create_path_mapping_config(%{
        remote_prefix: "/downloads/complete",
        local_prefix: "/data/torrents/complete"
      })

    assert Enum.any?(
             Settings.list_path_mapping_configs(),
             &(&1.remote_prefix == "/downloads/complete")
           )
  end
end

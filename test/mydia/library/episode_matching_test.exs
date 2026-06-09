defmodule Mydia.Library.EpisodeMatchingTest do
  use Mydia.DataCase, async: true

  import Mydia.Factory

  alias Mydia.Library
  alias Mydia.Library.MediaFile
  alias Mydia.Repo

  defp media_file_for(show, library_path, relative_path) do
    {:ok, file} =
      %MediaFile{}
      |> MediaFile.changeset(%{
        media_item_id: show.id,
        library_path_id: library_path.id,
        relative_path: relative_path,
        path: "/series/#{relative_path}",
        size: 1_000_000
      })
      |> Repo.insert()

    file
  end

  describe "match_files_to_episodes/1 title guard" do
    setup do
      show = insert(:tv_show, %{title: "FROM", year: 2022})
      episode = insert(:episode, %{media_item: show, season_number: 4, episode_number: 7})
      library_path = insert(:library_path, %{type: :series})

      {:ok, show: show, episode: episode, library_path: library_path}
    end

    test "does not bind a file whose title belongs to a different show", %{
      show: show,
      episode: episode,
      library_path: library_path
    } do
      # A stray "Shark Tank India" file carrying an S04E07 pattern must not be
      # assigned to "FROM" S04E07 purely because the episode number matches.
      file =
        media_file_for(
          show,
          library_path,
          "Shark_Tank_India_S04E07_From_Culinary_To_Creativity_1080p_SLIV_WEB.mp4"
        )

      assert {:ok, 0} = Library.match_files_to_episodes(show.id)

      reloaded = Repo.get!(MediaFile, file.id)
      assert reloaded.episode_id == nil
      refute reloaded.episode_id == episode.id
    end

    test "binds a genuine episode file for the show", %{
      show: show,
      episode: episode,
      library_path: library_path
    } do
      file = media_file_for(show, library_path, "From.S04E07.1080p.WEB.mp4")

      assert {:ok, 1} = Library.match_files_to_episodes(show.id)

      reloaded = Repo.get!(MediaFile, file.id)
      assert reloaded.episode_id == episode.id
    end

    test "binds an episode file with no parsed show title", %{
      show: show,
      episode: episode,
      library_path: library_path
    } do
      # A bare "S04E07" file has no title to contradict the show, so it is
      # still matched on the episode number.
      file = media_file_for(show, library_path, "S04E07.mkv")

      assert {:ok, 1} = Library.match_files_to_episodes(show.id)

      reloaded = Repo.get!(MediaFile, file.id)
      assert reloaded.episode_id == episode.id
    end
  end
end

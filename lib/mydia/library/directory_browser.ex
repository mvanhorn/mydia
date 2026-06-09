defmodule Mydia.Library.DirectoryBrowser do
  @moduledoc """
  Server-side filesystem directory suggestions for admin path inputs.

  Given a partially-typed path, returns immediate subdirectories that match,
  scoped to the deepest existing parent directory. Only directories are
  returned (never files), the scan is bounded to a single directory's
  immediate children (never recursive), and unreadable or missing paths
  yield an empty list rather than crashing.
  """

  @max_suggestions 25

  @doc """
  Suggests existing subdirectories for a partially-typed `input` path.

  Behaviour:

    * An empty or non-absolute input suggests the top-level directories under
      `/` (so typing nothing still offers a starting point).
    * When `input` ends in `/` (e.g. `/data/`), lists the immediate
      subdirectories of that directory.
    * Otherwise splits into parent + partial leaf (e.g. `/data/mo` ->
      parent `/data`, leaf `mo`) and lists the parent's subdirectories whose
      name starts with the leaf.

  Always returns full absolute paths, sorted, capped at #{@max_suggestions}.
  Returns `[]` for missing/unreadable parents.
  """
  @spec suggest(String.t() | nil) :: [String.t()]
  def suggest(nil), do: suggest("")

  def suggest(input) when is_binary(input) do
    {dir, prefix} = split_input(input)

    dir
    |> list_subdirectories()
    |> Enum.filter(&String.starts_with?(Path.basename(&1), prefix))
    |> Enum.sort()
    |> Enum.take(@max_suggestions)
  end

  @doc """
  Lists the immediate subdirectories of `dir` as full absolute paths.

  Returns `[]` when `dir` does not exist, is not a directory, or cannot be
  read. Never recurses and never returns regular files.
  """
  @spec list_subdirectories(String.t()) :: [String.t()]
  def list_subdirectories(dir) when is_binary(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        entries
        |> Enum.map(&Path.join(dir, &1))
        |> Enum.filter(&File.dir?/1)

      {:error, _reason} ->
        []
    end
  end

  # Splits a typed path into the existing directory to scan and the partial
  # leaf name to match against. Non-absolute input is treated as empty.
  defp split_input(input) do
    cond do
      input == "" or not String.starts_with?(input, "/") ->
        {"/", ""}

      String.ends_with?(input, "/") ->
        {Path.dirname(input <> "x"), ""}

      true ->
        {Path.dirname(input), Path.basename(input)}
    end
  end
end

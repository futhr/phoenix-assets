defmodule PhoenixAssets.Manifest do
  @moduledoc """
  Parses and queries a Vite build manifest.

  Vite writes a `manifest.json` keyed by source path; each entry records its
  hashed output `file`, its `css`, and the chunk `imports` it depends on (by
  manifest key). This module resolves those relationships -- recursively
  following `imports` and de-duplicating -- so a caller can ask "for this entry,
  what stylesheet links, script src, and module preloads do I emit?".

  All returned paths are prefixed with `/` (Vite emits them relative to the
  served static root).

  ## Why

  Hashed filenames change every build, so HTML must not hard-code them. Reading
  the manifest is how Phoenix emits correct `<script>`/`<link>` tags in
  production without coupling to specific hashes.
  """

  @type t :: %{optional(String.t()) => map()}

  @doc "Loads and decodes a Vite manifest from `path`."
  @spec load(Path.t()) :: {:ok, t()} | {:error, term()}
  def load(path) do
    with {:ok, raw} <- File.read(path) do
      JSON.decode(raw)
    end
  end

  @doc "Fetches the raw chunk for `key`, raising `KeyError` if it is absent."
  @spec entry!(t(), String.t()) :: map()
  def entry!(manifest, key) do
    case Map.fetch(manifest, key) do
      {:ok, chunk} -> chunk
      :error -> raise KeyError, key: key, term: manifest
    end
  end

  @doc "The hashed output file for `key` (prefixed with `/`)."
  @spec file(t(), String.t()) :: String.t()
  def file(manifest, key), do: manifest |> entry!(key) |> Map.fetch!("file") |> prefix()

  @doc """
  All stylesheet hrefs for `key`, including those of its transitive imports.

  Raises `KeyError` when `key` itself is absent (like `file/2` and
  `imports/2`); transitive imports that are missing from the manifest are
  skipped.
  """
  @spec css(t(), String.t()) :: [String.t()]
  def css(manifest, key) do
    _ = entry!(manifest, key)
    {_, _, css} = gather(manifest, key, MapSet.new())
    css |> Enum.uniq() |> Enum.map(&prefix/1)
  end

  @doc "Transitively imported chunk files for `key`, excluding its own file."
  @spec imports(t(), String.t()) :: [String.t()]
  def imports(manifest, key) do
    own = entry!(manifest, key)["file"]
    {_, files, _} = gather(manifest, key, MapSet.new())

    files
    |> List.delete(own)
    |> Enum.uniq()
    |> Enum.map(&prefix/1)
  end

  @doc "Module preload targets for `key` (its transitively imported chunk files)."
  @spec preload_links(t(), String.t()) :: [String.t()]
  def preload_links(manifest, key), do: imports(manifest, key)

  @doc """
  Subresource-integrity hashes for `key`, keyed by served href.

  Returns a map of `href => integrity` for the entry's own file and its
  transitively imported chunk files, for every chunk that carries an `integrity`
  field. Vite emits that field only when an SRI plugin is configured, so the map
  is empty otherwise -- callers render `integrity`/`crossorigin` only when a hash
  is present.
  """
  @spec subresource_integrity(t(), String.t()) :: %{String.t() => String.t()}
  def subresource_integrity(manifest, key) do
    {_, integrities} = collect_integrity(manifest, key, MapSet.new(), %{})
    integrities
  end

  defp collect_integrity(manifest, key, visited, acc) do
    if MapSet.member?(visited, key) do
      {visited, acc}
    else
      chunk = Map.get(manifest, key, %{})
      visited = MapSet.put(visited, key)

      acc =
        if is_binary(chunk["file"]) and is_binary(chunk["integrity"]) do
          Map.put(acc, prefix(chunk["file"]), chunk["integrity"])
        else
          acc
        end

      chunk
      |> Map.get("imports", [])
      |> Enum.reduce({visited, acc}, fn import, {v, a} ->
        collect_integrity(manifest, import, v, a)
      end)
    end
  end

  defp gather(manifest, key, visited) do
    if MapSet.member?(visited, key) do
      {visited, [], []}
    else
      chunk = Map.get(manifest, key, %{})
      visited = MapSet.put(visited, key)

      {visited, import_files, import_css} =
        chunk
        |> Map.get("imports", [])
        |> Enum.reduce({visited, [], []}, fn import, {v, files, css} ->
          {v, f, c} = gather(manifest, import, v)
          {v, files ++ f, css ++ c}
        end)

      own_files = if chunk["file"], do: [chunk["file"]], else: []
      {visited, own_files ++ import_files, Map.get(chunk, "css", []) ++ import_css}
    end
  end

  defp prefix("/" <> _ = path), do: path
  defp prefix("http://" <> _ = url), do: url
  defp prefix("https://" <> _ = url), do: url
  defp prefix(path), do: "/" <> path
end

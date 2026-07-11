defmodule PhoenixAssets.Manifest do
  @moduledoc """
  Parses and queries a Vite build manifest.

  Vite writes a `manifest.json` keyed by source path; each entry records its
  hashed output `file`, its `css`, and the chunk `imports` it depends on (by
  manifest key). This module resolves those relationships -- recursively
  following `imports` and de-duplicating -- so a caller can ask "for this entry,
  what stylesheet links, script src, and module preloads do I emit?".

  Root-relative paths are prefixed with `/` (Vite emits them relative to the
  served static root); absolute `http(s)://` URLs -- an entry Vite resolves to a
  CDN origin -- pass through unchanged.

  The query functions (`file/2`, `css/2`, `imports/2`, `subresource_integrity/2`)
  all raise `KeyError` when the requested top-level `key` is absent; transitive
  imports missing from the manifest are skipped.

  """

  alias PhoenixAssets.Telemetry

  @type t :: %{optional(String.t()) => map()}

  @doc "Loads and decodes a Vite manifest from `path`."
  @spec load(Path.t()) :: {:ok, t()} | {:error, term()}
  def load(path) do
    with {:ok, raw} <- File.read(path),
         {:ok, manifest} when is_map(manifest) <- JSON.decode(raw) do
      Telemetry.execute([:manifest, :load], %{entries: map_size(manifest)}, %{path: path})
      {:ok, manifest}
    else
      {:ok, value} -> {:error, {:invalid_manifest, value}}
      error -> error
    end
  end

  @doc """
  Fetches the raw chunk for `key`, raising `KeyError` if it is absent.

  A missing key also emits `[:phoenix_assets, :manifest, :missing_entry]`, so
  production observability catches requests for entries the build no longer
  produces.
  """
  @spec entry!(t(), String.t()) :: map()
  def entry!(manifest, key) do
    case Map.fetch(manifest, key) do
      {:ok, chunk} ->
        chunk

      :error ->
        Telemetry.execute([:manifest, :missing_entry], %{}, %{entry: key})
        raise KeyError, key: key, term: manifest
    end
  end

  @doc ~S"""
  The hashed output file for `key` (prefixed with `/`).

      iex> manifest = %{"src/app.ts" => %{"file" => "assets/app-Cw3Qz1.js"}}
      iex> PhoenixAssets.Manifest.file(manifest, "src/app.ts")
      "/assets/app-Cw3Qz1.js"
  """
  @spec file(t(), String.t()) :: String.t()
  def file(manifest, key), do: manifest |> entry!(key) |> Map.fetch!("file") |> prefix()

  @doc """
  All stylesheet hrefs for `key`, including those of its transitive imports.

  Raises `KeyError` when `key` itself is absent (like `file/2` and
  `imports/2`); transitive imports that are missing from the manifest are
  skipped.

      iex> manifest = %{"src/app.ts" => %{"file" => "assets/app.js", "css" => ["assets/app.css"]}}
      iex> PhoenixAssets.Manifest.css(manifest, "src/app.ts")
      ["/assets/app.css"]
  """
  @spec css(t(), String.t()) :: [String.t()]
  def css(manifest, key) do
    _ = entry!(manifest, key)
    {_, css, _} = collect(manifest, key)
    css |> Enum.uniq() |> Enum.map(&prefix/1)
  end

  @doc "Transitively imported chunk files for `key`, excluding its own file."
  @spec imports(t(), String.t()) :: [String.t()]
  def imports(manifest, key) do
    own = entry!(manifest, key)["file"]
    {files, _, _} = collect(manifest, key)

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

  Raises `KeyError` when `key` itself is absent (like `file/2`, `css/2`, and
  `imports/2`).

      iex> manifest = %{"src/app.ts" => %{"file" => "assets/app.js", "integrity" => "sha384-abc"}}
      iex> PhoenixAssets.Manifest.subresource_integrity(manifest, "src/app.ts")
      %{"/assets/app.js" => "sha384-abc"}
  """
  @spec subresource_integrity(t(), String.t()) :: %{String.t() => String.t()}
  def subresource_integrity(manifest, key) do
    _ = entry!(manifest, key)
    {_, _, integrity} = collect(manifest, key)
    integrity
  end

  # Single visited-set graph walk over `key` and its transitive imports,
  # gathering chunk files, stylesheet hrefs, and SRI hashes in one pass. Files
  # and css are prepended in pre-order and reversed once (no quadratic append).
  defp collect(manifest, key) do
    {_, files, css, integrity} =
      walk(manifest, key, {%{}, [], [], %{}})

    {Enum.reverse(files), Enum.reverse(css), integrity}
  end

  defp walk(manifest, key, {visited, files, css, integrity} = acc) do
    if Map.has_key?(visited, key) do
      acc
    else
      chunk = Map.get(manifest, key, %{})
      visited = Map.put(visited, key, true)

      files = if chunk["file"], do: [chunk["file"] | files], else: files
      css = chunk |> Map.get("css", []) |> Enum.reduce(css, &[&1 | &2])

      integrity =
        if is_binary(chunk["file"]) and is_binary(chunk["integrity"]) do
          Map.put(integrity, prefix(chunk["file"]), chunk["integrity"])
        else
          integrity
        end

      chunk
      |> Map.get("imports", [])
      |> Enum.reduce({visited, files, css, integrity}, fn import, a ->
        walk(manifest, import, a)
      end)
    end
  end

  defp prefix("/" <> _ = path), do: path
  defp prefix("http://" <> _ = url), do: url
  defp prefix("https://" <> _ = url), do: url
  defp prefix(path), do: "/" <> path
end

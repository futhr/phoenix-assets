defmodule PhoenixAssets.Generated do
  @moduledoc """
  Writes plugin-contributed TypeScript contracts to disk.

  Walks the initialised plugins, collects every `PhoenixAssets.GeneratedFile`
  they contribute, and writes each one -- but only when its contents actually
  changed. This content-gated write is what keeps the Vite HMR graph quiet: a
  regeneration that produces byte-identical output performs no writes and triggers
  no hot update.

  `generate/2` with `check: true` performs the same collection but compares
  against disk without writing, returning `{:error, {:stale, paths}}` when the
  on-disk contracts drift from what the current Phoenix/Ash definitions would
  produce. This powers the `mix phoenix_assets.gen --check` CI gate.

  ## Determinism

  Generators must emit byte-identical output for identical inputs (stable
  ordering, no timestamps in the body). The engine relies on this: it is the
  contract that makes both the no-write fast path and the drift check meaningful.

  ## See also

    * `PhoenixAssets.Generated.Watcher` -- regenerates on backend change in dev.
    * `PhoenixAssets.Engine` -- plugin initialisation and fan-out.
  """

  alias PhoenixAssets.{Context, Engine, GeneratedFile, Telemetry}

  @type generate_result :: %{written: [Path.t()], unchanged: [Path.t()]}

  @doc """
  Generates (or, with `check: true`, verifies) all frontend contracts.

  Returns `{:ok, %{written: [...], unchanged: [...]}}` on a write run, or
  `:ok | {:error, {:stale, paths}}` on a check run. Returns
  `{:error, {plugin, reason}}` if a plugin fails to initialise.
  """
  @spec generate(Context.t(), keyword()) ::
          {:ok, generate_result()} | :ok | {:error, term()}
  def generate(%Context{} = ctx, opts \\ []) do
    check? = Keyword.get(opts, :check, false)
    metadata = %{otp_app: ctx.otp_app, check: check?}

    Telemetry.span([:generated], metadata, fn ->
      result = do_generate(ctx, opts)
      {result, Map.merge(metadata, telemetry_metadata(result))}
    end)
  end

  @doc "Returns whether generated contracts differ from disk. Raises if generation fails."
  @spec stale?(Context.t()) :: boolean()
  def stale?(%Context{} = ctx) do
    case generate(ctx, check: true) do
      :ok ->
        false

      {:error, {:stale, _}} ->
        true

      {:error, reason} ->
        raise "phoenix_assets: cannot determine generated freshness: #{inspect(reason)}"
    end
  end

  @doc "Returns which generated files are fresh and which are stale, by relative path."
  @spec status(Context.t()) :: %{fresh: [Path.t()], stale: [Path.t()]} | {:error, term()}
  def status(%Context{} = ctx) do
    with {:ok, files} <- collect_files(ctx, nil) do
      {fresh, stale} = Enum.split_with(files, &fresh?(&1, ctx))
      %{fresh: Enum.map(fresh, & &1.path), stale: Enum.map(stale, & &1.path)}
    end
  end

  defp do_generate(ctx, opts) do
    with {:ok, files} <- collect_files(ctx, Keyword.get(opts, :only)) do
      if Keyword.get(opts, :check, false), do: check(files, ctx), else: write(files, ctx)
    end
  end

  defp collect_files(ctx, only) do
    with {:ok, initialized} <- Engine.init_plugins(ctx) do
      files =
        ctx
        |> Engine.collect(initialized, :generated_files)
        |> filter_only(only)
        |> Enum.sort_by(& &1.path)

      ensure_unique_paths(files, ctx)
    end
  end

  defp ensure_unique_paths(files, ctx) do
    # Validate every destination before any write or removal, including aliases
    # such as `a/../same.ts` that resolve to the same file.
    grouped = Enum.group_by(files, &abs_path!(&1, ctx))

    case grouped |> Enum.sort() |> Enum.find(fn {_, group} -> length(group) > 1 end) do
      nil -> {:ok, files}
      {_, [%GeneratedFile{path: path} | _]} -> {:error, {:duplicate_generated_file, path}}
    end
  end

  defp filter_only(files, nil), do: files
  defp filter_only(files, kinds), do: Enum.filter(files, &(&1.kind in kinds))

  defp write(files, ctx) do
    results = Enum.map(files, &write_if_changed(&1, ctx))

    {:ok,
     %{
       written: for({:written, path} <- results, do: path),
       unchanged: for({:unchanged, path} <- results, do: path)
     }}
  end

  defp write_if_changed(%GeneratedFile{} = file, ctx) do
    abs = abs_path!(file, ctx)
    contents = IO.iodata_to_binary(file.contents)

    case File.read(abs) do
      {:ok, ^contents} ->
        {:unchanged, file.path}

      _ ->
        File.mkdir_p!(Path.dirname(abs))
        atomic_write!(abs, contents)
        {:written, file.path}
    end
  end

  # Temp-file-plus-rename in the same directory: the rename is atomic on the
  # same filesystem, so the Vite watcher can never observe a half-written
  # contract mid-HMR.
  defp atomic_write!(abs, contents) do
    tmp = "#{abs}.tmp.#{System.unique_integer([:positive])}"

    try do
      File.write!(tmp, contents)
      File.rename!(tmp, abs)
    after
      File.rm(tmp)
    end
  end

  defp check(files, ctx) do
    case files |> Enum.reject(&fresh?(&1, ctx)) |> Enum.map(& &1.path) do
      [] ->
        :ok

      stale ->
        Telemetry.execute(
          [:generated, :stale],
          %{stale: length(stale)},
          %{otp_app: ctx.otp_app, stale: stale}
        )

        {:error, {:stale, stale}}
    end
  end

  @doc """
  Removes the files the configured plugins generate.

  Returns `{:ok, %{removed: [...], kept: [...]}}`, where `kept` lists paths that
  exist but whose contents differ from what the plugins would emit right now.
  Those are left alone: a host co-locating its own artifacts in the generated
  directory, or a contract someone edited by hand, should not be destroyed by a
  cleanup. Nothing outside the plugins' own file list is touched at all.
  """
  @spec clean(Context.t()) ::
          {:ok, %{removed: [Path.t()], kept: [Path.t()]}} | {:error, term()}
  def clean(%Context{} = ctx) do
    with {:ok, files} <- collect_files(ctx, nil) do
      {removed, kept} =
        files
        |> Enum.filter(&File.exists?(abs_path!(&1, ctx)))
        |> Enum.split_with(&fresh?(&1, ctx))

      Enum.each(removed, &File.rm!(abs_path!(&1, ctx)))

      {:ok, %{removed: Enum.map(removed, & &1.path), kept: Enum.map(kept, & &1.path)}}
    end
  end

  defp fresh?(%GeneratedFile{} = file, ctx) do
    abs = abs_path!(file, ctx)
    File.read(abs) == {:ok, IO.iodata_to_binary(file.contents)}
  end

  # Resolves the absolute path for a generated file and refuses to escape the
  # asset root. `PhoenixAssets.Plugin` is a public extension point, so a plugin
  # returning `path: "../x"` must not let it write (or read) outside `asset_root`.
  defp abs_path!(%GeneratedFile{path: rel}, %Context{asset_root: asset_root}) do
    root = Path.expand(asset_root)
    abs = Path.expand(Path.join(root, rel))

    if Path.type(rel) == :relative and abs != root and String.starts_with?(abs, root <> "/") do
      reject_symlinks!(root, Path.relative_to(abs, root))
      abs
    else
      raise ArgumentError,
            "phoenix_assets: generated file path #{inspect(rel)} escapes the asset root #{inspect(root)}"
    end
  end

  # Generated destinations below the configured root may not traverse symlinks.
  # The root itself may be a host-managed symlink. This is a preflight guard,
  # not protection against another process concurrently replacing directories.
  defp reject_symlinks!(root, relative) do
    Enum.reduce(Path.split(relative), root, fn segment, parent ->
      path = Path.join(parent, segment)

      case File.lstat(path) do
        {:ok, %{type: :symlink}} ->
          raise ArgumentError,
                "phoenix_assets: generated file path traverses symlink #{inspect(path)}"

        _ ->
          path
      end
    end)
  end

  defp telemetry_metadata({:ok, %{written: written, unchanged: unchanged}}),
    do: %{written: length(written), unchanged: length(unchanged)}

  defp telemetry_metadata({:error, {:stale, stale}}), do: %{stale: length(stale)}
  defp telemetry_metadata(_), do: %{}
end

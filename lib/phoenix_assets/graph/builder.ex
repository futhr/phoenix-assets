defmodule PhoenixAssets.Graph.Builder do
  @moduledoc """
  Assembles the Phoenix Asset Graph map from plugins and the Vite manifest.

  Collects every plugin's `graph_entries/2`, groups them by kind (pages, routes,
  stories, electric shapes, pubsub topics, locales), merges every plugin's
  `vite_config/2` patch into the `"vite"` section, and merges the Vite
  manifest's entry chunks. The result is a plain map ready to be encoded as
  `graph.json` (key ordering is applied by the canonical encoder at write time).

  ## Why

  Keeping assembly separate from I/O (`PhoenixAssets.Graph` owns reading/writing)
  makes the graph shape easy to test in isolation: feed a context and an optional
  manifest, get a deterministic map back.
  """

  require Logger

  alias PhoenixAssets.{Context, Engine, Manifest, Telemetry}
  alias PhoenixAssets.Graph.Entry

  @doc """
  Builds the asset-graph map.

  Options:

    * `:manifest` -- a pre-loaded Vite manifest map (otherwise loaded from the
      configured `:vite_manifest` path; absent in development).
  """
  @spec build(Context.t(), keyword()) :: map()
  def build(%Context{} = ctx, opts \\ []) do
    {entries, vite} = collect_plugins(ctx)

    %{
      "version" => 1,
      "app" => to_string(ctx.otp_app),
      "entries" => manifest_entries(ctx, opts),
      "vite" => vite,
      "pages" => group(entries, :page),
      "routes" => group(entries, :route),
      "stories" => group(entries, :story),
      "electric_shapes" => group(entries, :electric_shape),
      "pubsub_topics" => group(entries, :pubsub_topic),
      "locales" => group(entries, :locale)
    }
  end

  defp collect_plugins(ctx) do
    case Engine.init_plugins(ctx) do
      {:ok, initialized} ->
        {Engine.collect(ctx, initialized, :graph_entries),
         Engine.collect_map(ctx, initialized, :vite_config)}

      {:error, {module, reason}} ->
        Logger.error(
          "phoenix_assets: asset graph is incomplete — plugin #{inspect(module)} " <>
            "failed to initialise: #{inspect(reason)}"
        )

        Telemetry.execute([:graph, :degraded], %{}, %{
          reason: :plugin_init_failed,
          plugin: module,
          error: reason
        })

        {[], %{}}
    end
  end

  defp group(entries, kind) do
    entries
    |> Enum.filter(&(&1.kind == kind))
    |> Map.new(fn entry -> {entry.key, payload(entry)} end)
  end

  defp payload(%Entry{data: data, source: nil}), do: data
  defp payload(%Entry{data: data, source: source}), do: Map.put(data, "source", source)

  defp manifest_entries(ctx, opts) do
    case resolve_manifest(ctx, opts) do
      {:ok, manifest} ->
        manifest
        |> Enum.filter(fn {_, chunk} -> chunk["isEntry"] end)
        |> Map.new(fn {key, _} ->
          {key,
           %{
             "file" => Manifest.file(manifest, key),
             "css" => Manifest.css(manifest, key),
             "imports" => Manifest.imports(manifest, key)
           }}
        end)

      :absent ->
        %{}

      {:error, reason} ->
        Telemetry.execute([:graph, :degraded], %{}, %{
          reason: :manifest_unreadable,
          path: Context.manifest_path(ctx),
          error: reason
        })

        %{}
    end
  end

  # A pre-loaded manifest (the production write path) is trusted as-is. Otherwise
  # the configured manifest is read from disk, distinguishing `:absent` (no file
  # -- the normal development case, silent) from `{:error, _}` (a file that exists
  # but cannot be read or parsed -- a real problem worth a telemetry event).
  defp resolve_manifest(ctx, opts) do
    case Keyword.fetch(opts, :manifest) do
      {:ok, manifest} when is_map(manifest) -> {:ok, manifest}
      {:ok, _} -> :absent
      :error -> load_manifest(ctx)
    end
  end

  defp load_manifest(ctx) do
    case Manifest.load(Context.manifest_path(ctx)) do
      {:ok, manifest} -> {:ok, manifest}
      {:error, :enoent} -> :absent
      {:error, reason} -> {:error, reason}
    end
  end
end

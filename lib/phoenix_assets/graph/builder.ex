defmodule PhoenixAssets.Graph.Builder do
  @moduledoc """
  Assembles the Phoenix Asset Graph map from plugins and the Vite manifest.

  Collects every plugin's `graph_entries/2`, groups them by kind (pages, routes,
  stories, electric shapes, pubsub topics, locales) into key-sorted maps, and
  merges the Vite manifest's entry chunks. The result is a plain map ready to be
  encoded as `graph.json`.

  ## Why

  Keeping assembly separate from I/O (`PhoenixAssets.Graph` owns reading/writing)
  makes the graph shape easy to test in isolation: feed a context and an optional
  manifest, get a deterministic map back.
  """

  require Logger

  alias PhoenixAssets.{Context, Engine, Manifest}
  alias PhoenixAssets.Graph.Entry

  @doc """
  Builds the asset-graph map.

  Options:

    * `:manifest` -- a pre-loaded Vite manifest map (otherwise loaded from the
      configured `:vite_manifest` path; absent in development).
  """
  @spec build(Context.t(), keyword()) :: map()
  def build(%Context{} = ctx, opts \\ []) do
    entries = graph_entries(ctx)

    %{
      "version" => 1,
      "app" => to_string(ctx.otp_app),
      "entries" => manifest_entries(ctx, opts),
      "pages" => group(entries, :page),
      "routes" => group(entries, :route),
      "stories" => group(entries, :story),
      "electric_shapes" => group(entries, :electric_shape),
      "pubsub_topics" => group(entries, :pubsub_topic),
      "locales" => group(entries, :locale)
    }
  end

  defp graph_entries(ctx) do
    case Engine.init_plugins(ctx) do
      {:ok, initialized} ->
        Engine.collect(ctx, initialized, :graph_entries)

      {:error, {module, reason}} ->
        Logger.error(
          "phoenix_assets: asset graph is incomplete — plugin #{inspect(module)} " <>
            "failed to initialise: #{inspect(reason)}"
        )

        []
    end
  end

  defp group(entries, kind) do
    entries
    |> Enum.filter(&(&1.kind == kind))
    |> Enum.sort_by(& &1.key)
    |> Map.new(fn entry -> {entry.key, payload(entry)} end)
  end

  defp payload(%Entry{data: data, source: nil}), do: data
  defp payload(%Entry{data: data, source: source}), do: Map.put(data, "source", source)

  defp manifest_entries(ctx, opts) do
    case opts[:manifest] || load_manifest(ctx) do
      manifest when is_map(manifest) ->
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

      _ ->
        %{}
    end
  end

  defp load_manifest(ctx) do
    case Manifest.load(Context.manifest_path(ctx)) do
      {:ok, manifest} -> manifest
      _ -> nil
    end
  end
end

defmodule PhoenixAssets.Graph do
  @moduledoc """
  The Phoenix Asset Graph: one artifact linking Phoenix concepts to build output.

  The graph answers cross-cutting questions a single tool cannot: which route maps
  to which page, which Vite entry loads it, which stylesheet and preloads it
  needs, which Storybook story covers it, which Electric shape and PubSub topic it
  depends on, which locale bundle it requires. It is assembled from the Vite
  manifest (build output) plus the `graph_entries/2` every plugin contributes,
  and written to a JSON file consumed by tooling, the doctor, and the optional
  compiled lookup module.

  ## Why

  Without one graph, this knowledge is scattered across the router, the Svelte
  routes, the shape declarations, and the manifest. Materialising it once makes
  provenance and production validation possible.

  ## See also

    * `PhoenixAssets.Graph.Builder` -- assembles the graph map.
    * `PhoenixAssets.Graph.Compiled` -- compiles it into a zero-cost lookup module.
  """

  alias PhoenixAssets.{CanonicalJSON, Context}
  alias PhoenixAssets.Graph.Builder

  # Deliberately OUTSIDE priv/static: the graph names every route, shape, and
  # topic the app has, and anything under priv/static/assets is publicly served
  # by the default Plug.Static `:only` list. priv/ still ships with releases, so
  # runtime lookups keep working.
  @default_path "priv/phoenix_assets/graph.json"

  @doc "Builds the asset-graph map. See `PhoenixAssets.Graph.Builder.build/2` for options."
  @spec build(Context.t(), keyword()) :: map()
  def build(%Context{} = ctx, opts \\ []), do: Builder.build(ctx, opts)

  @doc """
  Builds and writes the asset graph to its JSON file, returning the path.

  Output is canonical (`PhoenixAssets.CanonicalJSON`) and the write is atomic
  (temp file + rename), so a concurrent reader never observes a partial graph
  and identical input always produces identical bytes.
  """
  @spec write(Context.t(), keyword()) :: {:ok, Path.t()}
  def write(%Context{} = ctx, opts \\ []) do
    path = graph_path(ctx)
    File.mkdir_p!(Path.dirname(path))
    tmp = "#{path}.tmp.#{System.unique_integer([:positive])}"
    File.write!(tmp, CanonicalJSON.encode!(build(ctx, opts)))
    File.rename!(tmp, path)
    {:ok, path}
  end

  @doc "Loads the asset graph from its JSON file."
  @spec load(Context.t()) :: {:ok, map()} | {:error, term()}
  def load(%Context{} = ctx) do
    with {:ok, raw} <- File.read(graph_path(ctx)) do
      JSON.decode(raw)
    end
  end

  @doc """
  The on-disk path of the asset graph for this context.

  Defaults to `priv/phoenix_assets/graph.json` (relative to the project root);
  override with `config :phoenix_assets, :build, asset_graph: path`. The
  default lives outside `priv/static` so the graph is packaged with releases
  without being publicly served.
  """
  @spec graph_path(Context.t()) :: Path.t()
  def graph_path(%Context{} = ctx) do
    Keyword.get(ctx.config.build, :asset_graph, @default_path)
  end
end

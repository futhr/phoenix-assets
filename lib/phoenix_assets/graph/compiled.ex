defmodule PhoenixAssets.Graph.Compiled do
  @moduledoc """
  Compiles the asset graph into a module for zero-cost runtime lookups.

  `use PhoenixAssets.Graph.Compiled, graph: path` reads `graph.json` at *compile
  time*, embeds it, and defines `graph/0`, `entry!/1`, `page!/1`, and `route!/1`.
  The graph file is registered as an `@external_resource`, so the module
  recompiles when it changes.

  ## Example

      defmodule MyAppWeb.Generated.Assets do
        use PhoenixAssets.Graph.Compiled,
          graph: "priv/static/assets/.phoenix-assets/graph.json"
      end

      MyAppWeb.Generated.Assets.route!("device_show")

  ## Why

  Reading and decoding JSON on every lookup is wasteful on hot paths. Compiling
  the graph into pattern data trades a recompile-on-change for allocation-free
  lookups at runtime.
  """

  @doc false
  defmacro __using__(opts) do
    path = Keyword.fetch!(opts, :graph)
    graph = path |> File.read!() |> Jason.decode!()

    quote do
      @external_resource unquote(path)

      @doc "The compiled asset graph."
      @spec graph() :: map()
      def graph, do: unquote(Macro.escape(graph))

      @doc "Fetches a manifest entry by key, raising if absent."
      @spec entry!(String.t()) :: map()
      def entry!(key), do: unquote(__MODULE__).fetch!(graph(), "entries", key)

      @doc "Fetches a page by name, raising if absent."
      @spec page!(String.t()) :: map()
      def page!(name), do: unquote(__MODULE__).fetch!(graph(), "pages", name)

      @doc "Fetches a route by name, raising if absent."
      @spec route!(String.t()) :: map()
      def route!(name), do: unquote(__MODULE__).fetch!(graph(), "routes", name)
    end
  end

  @doc false
  @spec fetch!(map(), String.t(), String.t()) :: map()
  def fetch!(graph, section, key) do
    case get_in(graph, [section, key]) do
      nil -> raise KeyError, key: key, term: "asset graph #{section}"
      value -> value
    end
  end
end

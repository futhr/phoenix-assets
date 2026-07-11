defmodule PhoenixAssets.Graph.Compiled do
  @moduledoc """
  Embeds the asset graph in a module for in-memory runtime lookups.

  `use PhoenixAssets.Graph.Compiled, graph: path` reads `graph.json` at *compile
  time*, embeds it, and defines `graph/0`, `entry!/1`, `page!/1`, and `route!/1`.
  The graph file is registered as an `@external_resource`, so the module
  recompiles when it changes.

  ## Example

      defmodule MyAppWeb.Generated.Assets do
        use PhoenixAssets.Graph.Compiled,
          graph: "priv/phoenix_assets/graph.json"
      end

      MyAppWeb.Generated.Assets.route!("device_show")

  > #### `use PhoenixAssets.Graph.Compiled` {: .info}
  >
  > Using this module reads the configured graph file at compile time, registers
  > it as an external resource, and defines `graph/0`, `entry!/1`, `page!/1`,
  > and `route!/1`.

  """

  @doc false
  defmacro __using__(opts) do
    path = Keyword.fetch!(opts, :graph)
    graph = read_graph!(path)

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

  # Reads and decodes the graph at compile time, raising a clear CompileError
  # (instead of a raw File.Error / JSON.DecodeError surfacing from inside the
  # macro) so a missing or malformed graph.json points the caller at the fix.
  @spec read_graph!(Path.t()) :: map()
  defp read_graph!(path) do
    case File.read(path) do
      {:ok, raw} ->
        case JSON.decode(raw) do
          {:ok, graph} ->
            graph

          {:error, reason} ->
            raise CompileError,
              description:
                "PhoenixAssets.Graph.Compiled: #{path} is not valid JSON " <>
                  "(#{inspect(reason)}). Run `mix phoenix_assets.gen` to regenerate it."
        end

      {:error, reason} ->
        raise CompileError,
          description:
            "PhoenixAssets.Graph.Compiled: cannot read graph file #{path} " <>
              "(#{inspect(reason)}). Run `mix phoenix_assets.gen` before compiling."
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

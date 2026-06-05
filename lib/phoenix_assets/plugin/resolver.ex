defmodule PhoenixAssets.Plugin.Resolver do
  @moduledoc """
  Resolves a list of plugins into a deterministic execution order.

  Given `{module, opts}` pairs in declaration order, the resolver reads each
  plugin's `depends_on` (hard) and `after_plugin` (soft) edges and produces a
  topological ordering via Kahn's algorithm. Ties (several plugins ready at once)
  break by declaration order, so the result is stable. A hard dependency that is
  absent fails with `{:missing_dependency, plugin, dependency}`; a cycle fails
  with `{:cycle, modules}`.

  ## Why

  Generation, dev startup, and graph building all walk plugins in the same order;
  Storybook must initialise after SvelteKit, Tailwind's Vite patch must precede
  others. Computing one deterministic order up front (and failing loudly on
  ambiguity) is what makes the whole engine reproducible.

  ## See also

    * `PhoenixAssets.Preset` -- runs this at compile time so cycles surface as
      compile errors.
  """

  @type plugin :: {module(), keyword()}
  @type error ::
          {:missing_dependency, module(), module()}
          | {:cycle, [module()]}

  @doc """
  Resolves plugins into topological order.

  Returns `{:ok, ordered_plugins}` preserving each plugin's opts, or
  `{:error, reason}`.
  """
  @spec resolve([plugin()]) :: {:ok, [plugin()]} | {:error, error()}
  def resolve(plugins) do
    modules = Enum.map(plugins, fn {m, _} -> m end)
    index = modules |> Enum.with_index() |> Map.new()
    set = MapSet.new(modules)

    with :ok <- check_missing(plugins, set) do
      edges = build_edges(plugins, set)
      indeg = indegrees(modules, edges)

      case kahn(modules, edges, indeg, index, []) do
        {:ok, order} ->
          opts_by_module = Map.new(plugins)
          {:ok, Enum.map(order, fn m -> {m, Map.fetch!(opts_by_module, m)} end)}

        {:error, remaining} ->
          {:error, {:cycle, remaining}}
      end
    end
  end

  @doc "Renders a resolver error as a human-readable string."
  @spec format_error(error()) :: String.t()
  def format_error({:missing_dependency, plugin, dependency}) do
    "#{inspect(plugin)} depends on #{inspect(dependency)}, which is not part of the preset"
  end

  def format_error({:cycle, modules}) do
    "dependency cycle among: " <> Enum.map_join(modules, ", ", &inspect/1)
  end

  defp check_missing(plugins, set) do
    Enum.reduce_while(plugins, :ok, fn {module, _}, :ok ->
      %{depends_on: deps} = module.__phoenix_assets_plugin__()

      case Enum.find(deps, &(not MapSet.member?(set, &1))) do
        nil -> {:cont, :ok}
        missing -> {:halt, {:error, {:missing_dependency, module, missing}}}
      end
    end)
  end

  defp build_edges(plugins, set) do
    Enum.reduce(plugins, %{}, fn {module, _}, edges ->
      %{depends_on: deps, after: afters} = module.__phoenix_assets_plugin__()
      befores = deps ++ Enum.filter(afters, &MapSet.member?(set, &1))

      Enum.reduce(befores, edges, fn before, acc ->
        Map.update(acc, before, MapSet.new([module]), &MapSet.put(&1, module))
      end)
    end)
  end

  defp indegrees(modules, edges) do
    base = Map.new(modules, &{&1, 0})

    Enum.reduce(edges, base, fn {_, successors}, indeg ->
      Enum.reduce(successors, indeg, fn successor, acc ->
        Map.update(acc, successor, 1, &(&1 + 1))
      end)
    end)
  end

  defp kahn([], _, _, _, acc), do: {:ok, Enum.reverse(acc)}

  defp kahn(remaining, edges, indeg, index, acc) do
    case Enum.filter(remaining, &(Map.get(indeg, &1, 0) == 0)) do
      [] ->
        {:error, remaining}

      ready ->
        next = Enum.min_by(ready, &Map.fetch!(index, &1))

        indeg =
          edges
          |> Map.get(next, MapSet.new())
          |> Enum.reduce(indeg, fn successor, acc -> Map.update!(acc, successor, &(&1 - 1)) end)

        kahn(List.delete(remaining, next), edges, indeg, index, [next | acc])
    end
  end
end

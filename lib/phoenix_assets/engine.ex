defmodule PhoenixAssets.Engine do
  @moduledoc """
  Initialises plugins and collects their declarations.

  The engine is the single place that turns a `PhoenixAssets.Context` (which
  carries the resolved-but-uninitialised plugin list) into initialised plugins,
  and gathers a given callback across all of them in order. The generators, the
  graph builder, the dev supervisor, and the doctor all build on these two
  primitives so plugin initialisation happens exactly once per operation and in
  the resolved order.

  ## Why

  Centralising `init/2` and callback fan-out keeps every subsystem consistent: a
  plugin's `init/2` side of state is computed once, and "ask every plugin for its
  X" is one well-tested function instead of four ad hoc reductions.
  """

  alias PhoenixAssets.Context

  @typedoc "A plugin after initialisation: `{module, opts, state}`."
  @type initialized :: {module(), keyword(), term()}

  @doc """
  Initialises every plugin in the context, in resolved order.

  Returns `{:ok, initialized}` or `{:error, {plugin_module, reason}}` on the
  first plugin whose `c:PhoenixAssets.Plugin.init/2` fails.
  """
  @spec init_plugins(Context.t()) :: {:ok, [initialized()]} | {:error, {module(), term()}}
  def init_plugins(%Context{plugins: plugins} = ctx) do
    plugins
    |> Enum.reduce_while({:ok, []}, fn {module, opts}, {:ok, acc} ->
      case module.init(opts, ctx) do
        {:ok, state} -> {:cont, {:ok, [{module, opts, state} | acc]}}
        {:error, reason} -> {:halt, {:error, {module, reason}}}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Calls `callback/2` on every initialised plugin and concatenates the results.

  `callback` is one of the list-returning `PhoenixAssets.Plugin` callbacks
  (`:generated_files`, `:dev_processes`, `:graph_entries`, `:doctor_checks`,
  `:runtime_modules`). Each plugin receives `(ctx, state)`.
  """
  @spec collect(Context.t(), [initialized()], atom()) :: [term()]
  def collect(%Context{} = ctx, initialized, callback) when is_atom(callback) do
    Enum.flat_map(initialized, fn {module, _, state} ->
      apply(module, callback, [ctx, state])
    end)
  end
end

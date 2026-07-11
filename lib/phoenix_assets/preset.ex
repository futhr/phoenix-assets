defmodule PhoenixAssets.Preset do
  @moduledoc """
  A deterministic composition of `PhoenixAssets.Plugin` integrations.

  A preset is a module that lists integrations; at compile time they are resolved
  into an ordered plugin graph and exposed via `plugins/0`. Because resolution
  happens at compile time, a dependency cycle or a missing hard dependency is a
  compile error in the preset module.

  ## Example

      defmodule MyApp.Assets.Stack do
        use PhoenixAssets.Preset

        integration PhoenixAssets.SvelteKit
        integration PhoenixAssets.Tailwind, entry: "src/app.css"
        integration PhoenixAssets.Storybook, port: 6006
        integration PhoenixAssets.Electric, shapes: MyApp.Assets.ElectricShapes
        integration PhoenixAssets.PubSub, topics: MyApp.Assets.PubSubTopics
        integration PhoenixAssets.Localize, locales: ~w(en sv), default_locale: "en"
      end

  `plugins/0` returns the resolved `{module, opts}` list. The built-in
  `PhoenixAssets.Presets.Svelte` is one such preset; its graph begins with the
  SvelteKit integration the others build on:

      iex> [{first, _opts} | _] = PhoenixAssets.Presets.Svelte.plugins()
      iex> first
      PhoenixAssets.SvelteKit

  > #### `use PhoenixAssets.Preset` {: .info}
  >
  > Using this module imports `integration/1` and `integration/2`. It defines
  > `plugins/0` at the end of compilation after resolving dependency and
  > ordering constraints.

  ## See also

    * `PhoenixAssets.Plugin` -- the integration contract.
    * `PhoenixAssets.Plugin.Resolver` -- the ordering algorithm.
  """

  alias PhoenixAssets.Plugin.Resolver

  @doc false
  defmacro __using__(_) do
    quote do
      import PhoenixAssets.Preset, only: [integration: 1, integration: 2]
      Module.register_attribute(__MODULE__, :phoenix_assets_integrations, accumulate: true)
      @before_compile PhoenixAssets.Preset
    end
  end

  @doc "Declares an integration (a `PhoenixAssets.Plugin` module) and its options."
  defmacro integration(module, opts \\ []) do
    quote do
      @phoenix_assets_integrations {unquote(module), unquote(opts)}
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    integrations =
      env.module
      |> Module.get_attribute(:phoenix_assets_integrations)
      |> List.wrap()
      |> Enum.reverse()

    case Resolver.resolve(integrations) do
      {:ok, ordered} ->
        escaped = Macro.escape(ordered)

        quote do
          @doc "The ordered, resolved `{plugin_module, opts}` list for this preset."
          @spec plugins() :: [{module(), keyword()}]
          def plugins, do: unquote(escaped)
        end

      {:error, reason} ->
        raise CompileError,
          file: env.file,
          line: env.line,
          description:
            "phoenix_assets preset #{inspect(env.module)} could not be resolved: " <>
              Resolver.format_error(reason)
    end
  end
end

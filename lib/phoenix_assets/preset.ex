defmodule PhoenixAssets.Preset do
  @moduledoc """
  A deterministic composition of `PhoenixAssets.Plugin` integrations.

  A preset is a module that lists integrations; at compile time they are resolved
  into an ordered plugin graph and exposed via `plugins/0`. Because resolution
  happens at compile time, a dependency cycle or a missing hard dependency is a
  *compile error* in the preset module -- the earliest possible feedback.

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

      iex> [{first, _opts} | _] = MyApp.Assets.Stack.plugins()
      iex> first
      PhoenixAssets.SvelteKit

  ## Why

  Listing integrations once, with their options, and resolving order
  deterministically removes the per-project guesswork of "which plugin runs
  first" and turns ordering bugs into compile errors instead of runtime surprises.

  ## Note

  Integration modules referenced by a preset must already be compiled when the
  preset compiles -- in practice they come from a dependency (the stack package),
  so this is automatic.

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

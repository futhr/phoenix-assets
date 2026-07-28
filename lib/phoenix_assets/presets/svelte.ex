defmodule PhoenixAssets.Presets.Svelte do
  @moduledoc """
  The built-in default preset: the full Svelte stack.

  Composes SvelteKit, Tailwind, Storybook, ElectricSQL, server commands, the
  session projection, Phoenix PubSub, localization, Ash-to-TypeScript types, and
  typespec-derived contracts into one ordered plugin graph. This is the preset
  `phoenix_assets` uses when the host application does not set its own
  `:preset`:

      # config/config.exs -- nothing to point at; this preset is the default.
      config :phoenix_assets,
        otp_app: :my_app,
        endpoint: MyAppWeb.Endpoint,
        router: MyAppWeb.Router

  The data-binding plugins read their host declaration modules from the `:stack`
  sub-config, so you enable them without writing a preset:

      config :phoenix_assets, :stack,
        shapes: MyApp.Assets.ElectricShapes,
        commands: MyApp.Assets.Commands,
        session: MyApp.Assets.Session,
        topics: MyApp.Assets.PubSubTopics,
        types: MyApp.Assets.Types

  To customise ordering or per-plugin options, write your own module with
  `use PhoenixAssets.Preset` and set it as `:preset` -- copy the integration list
  below as a starting point.

  ## See also

    * `PhoenixAssets.Preset` -- the composition DSL.
    * `PhoenixAssets.Config` -- resolves this preset when `:preset` is unset.
  """

  use PhoenixAssets.Preset

  integration(PhoenixAssets.SvelteKit)
  integration(PhoenixAssets.Tailwind)
  integration(PhoenixAssets.Storybook)
  integration(PhoenixAssets.Electric)
  integration(PhoenixAssets.Commands)
  integration(PhoenixAssets.Session)
  integration(PhoenixAssets.PubSub)
  integration(PhoenixAssets.Localize)
  integration(PhoenixAssets.Types)
  integration(PhoenixAssets.Typespec)
end

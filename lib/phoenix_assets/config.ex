defmodule PhoenixAssets.Config do
  @moduledoc """
  Validated, normalized configuration for `phoenix_assets`.

  Reads the host application's `config :phoenix_assets, ...` keys and returns a
  `t:t/0` struct. The top-level scalar keys are validated against a strict
  `NimbleOptions` schema; the nested sub-configs (`:dev`, `:build`, `:env`,
  `:dev_intelligence`, `:stack`) are captured as keyword lists for the subsystems
  that own their validation (the dev supervisor, the generators, the doctor).

  The `:env` sub-config (`config :phoenix_assets, :env, expose: [...]`) carries an
  `expose:` allow-list of constants surfaced to the frontend; it is stored on the
  `:env_expose` struct field and consumed by `PhoenixAssets.Generators.Env`.

  ## Example

      config :phoenix_assets,
        otp_app: :my_app,
        endpoint: MyAppWeb.Endpoint,
        router: MyAppWeb.Router,
        preset: MyApp.Assets.Stack

      iex> config = PhoenixAssets.Config.load!(otp_app: :my_app)
      iex> config.asset_root
      "assets"

  ## See also

    * `PhoenixAssets.Context` -- the per-run snapshot built from a config.
  """

  alias PhoenixAssets.Presets.Svelte

  @schema NimbleOptions.new!(
            otp_app: [type: :atom, required: true],
            endpoint: [type: :atom, doc: "the Phoenix endpoint module"],
            router: [
              type: :atom,
              doc: "the Phoenix router module (source for endpoint route helpers)"
            ],
            endpoint_prefixes: [
              type: {:list, :string},
              default: ["/shapes", "/api"],
              doc: "router path prefixes whose routes become generated endpoint helpers"
            ],
            asset_root: [type: :string, default: "assets"],
            static_root: [type: :string, default: "priv/static"],
            static_assets_path: [type: :string, default: "/assets"],
            generated_dir: [
              type: :string,
              default: "src/generated",
              doc:
                "directory (relative to asset_root) where generated TypeScript contracts are written"
            ],
            package_manager: [type: {:in, [:pnpm, :npm, :bun]}, default: :pnpm],
            js_runtime: [type: {:in, [:node, :bun]}, default: :node],
            ssr_runtime: [type: {:in, [:node, :bun]}, default: :node],
            preset: [type: :atom, doc: "a module that `use PhoenixAssets.Preset`"],
            serve_mode: [
              type: {:in, [:ssr, :spa]},
              default: :ssr,
              doc:
                "`:ssr` (default) renders HTML from the Vite manifest; `:spa` is an adapter-static " <>
                  "SvelteKit/SPA build that serves its own index.html and needs no server-rendered manifest"
            ]
          )

  @sub_keys [:dev, :build, :env, :dev_intelligence, :stack]

  @type t :: %__MODULE__{
          otp_app: atom(),
          endpoint: module() | nil,
          router: module() | nil,
          endpoint_prefixes: [String.t()],
          asset_root: String.t(),
          static_root: String.t(),
          static_assets_path: String.t(),
          generated_dir: String.t(),
          package_manager: :pnpm | :npm | :bun,
          js_runtime: :node | :bun,
          ssr_runtime: :node | :bun,
          preset: module() | nil,
          serve_mode: :ssr | :spa,
          dev: keyword(),
          build: keyword(),
          env_expose: keyword(),
          dev_intelligence: keyword(),
          stack: keyword()
        }

  @enforce_keys [:otp_app]
  defstruct otp_app: nil,
            endpoint: nil,
            router: nil,
            endpoint_prefixes: ["/shapes", "/api"],
            asset_root: "assets",
            static_root: "priv/static",
            static_assets_path: "/assets",
            generated_dir: "src/generated",
            package_manager: :pnpm,
            js_runtime: :node,
            ssr_runtime: :node,
            preset: nil,
            serve_mode: :ssr,
            dev: [],
            build: [],
            env_expose: [],
            dev_intelligence: [],
            stack: []

  @doc """
  Loads and validates configuration.

  Without arguments, reads `Application.get_all_env(:phoenix_assets)`. A keyword
  list may be passed instead (primarily for tests). Raises `NimbleOptions`
  validation errors for invalid scalar options.
  """
  @spec load!(keyword() | nil) :: t()
  def load!(opts \\ nil) do
    opts = opts || Application.get_all_env(:phoenix_assets)
    {sub, scalars} = Keyword.split(opts, @sub_keys)
    validated = NimbleOptions.validate!(scalars, @schema)

    struct!(
      __MODULE__,
      Keyword.merge(validated,
        dev: sub[:dev] || [],
        build: sub[:build] || [],
        env_expose: sub[:env] || [],
        dev_intelligence: sub[:dev_intelligence] || [],
        stack: sub[:stack] || []
      )
    )
  end

  @doc "The raw schema for the top-level scalar options, for documentation and tooling."
  @spec schema() :: keyword()
  def schema, do: @schema.schema

  @doc """
  Resolves the ordered `{plugin, opts}` list for a config.

  When the host has not configured a `:preset`, the built-in default preset
  `PhoenixAssets.Presets.Svelte` is used, so the full Svelte stack works without a
  hand-written preset module. Set `:preset` to compose a different stack.
  """
  @spec preset_plugins(t()) :: [{module(), keyword()}]
  def preset_plugins(%__MODULE__{preset: nil}), do: Svelte.plugins()
  def preset_plugins(%__MODULE__{preset: preset}), do: preset.plugins()
end

defmodule PhoenixAssets.Context do
  @moduledoc """
  The read-only snapshot threaded through every plugin callback.

  A context is built once per operation (generation, dev startup, doctor run,
  graph build) from a `PhoenixAssets.Config` plus the resolved plugin list and
  the runtime environment. Plugins receive it and must not mutate it -- they
  contribute declarations (`generated_files/2`, `dev_processes/2`,
  `graph_entries/2`, ...) computed from it.

  The most-used config fields are hoisted onto the context for ergonomics; the
  full `PhoenixAssets.Config` remains available as `:config` for less-common
  knobs.

  ## Why

  Passing one immutable struct (rather than the raw application environment) to
  plugins keeps them pure and testable: a plugin's output is a function of its
  context and its own state, with no hidden global reads.
  """

  alias PhoenixAssets.Config

  @type env :: :dev | :test | :prod
  @type resolved_plugin :: {module(), keyword()} | {module(), keyword(), term()}

  @type t :: %__MODULE__{
          otp_app: atom(),
          endpoint: module() | nil,
          router: module() | nil,
          asset_root: String.t(),
          static_root: String.t(),
          static_assets_path: String.t(),
          generated_dir: String.t(),
          package_manager: :pnpm | :npm | :bun,
          js_runtime: :node | :bun,
          ssr_runtime: :node | :bun,
          env: env(),
          config: Config.t(),
          plugins: [resolved_plugin()]
        }

  @enforce_keys [:config]
  defstruct [
    :otp_app,
    :endpoint,
    :router,
    :asset_root,
    :static_root,
    :static_assets_path,
    :generated_dir,
    :package_manager,
    :js_runtime,
    :ssr_runtime,
    :config,
    env: :prod,
    plugins: []
  ]

  @doc """
  Builds a context from a `PhoenixAssets.Config`.

  Options:

    * `:env` -- the runtime environment (`:dev | :test | :prod`), default `:prod`.
    * `:plugins` -- the resolved, ordered plugin list, default `[]`.
  """
  @spec new(Config.t(), keyword()) :: t()
  def new(%Config{} = config, opts \\ []) do
    %__MODULE__{
      otp_app: config.otp_app,
      endpoint: config.endpoint,
      router: config.router,
      asset_root: config.asset_root,
      static_root: config.static_root,
      static_assets_path: config.static_assets_path,
      generated_dir: config.generated_dir,
      package_manager: config.package_manager,
      js_runtime: config.js_runtime,
      ssr_runtime: config.ssr_runtime,
      config: config,
      env: Keyword.get(opts, :env, :prod),
      plugins: Keyword.get(opts, :plugins, [])
    }
  end

  @doc "Joins `rel` onto the asset root, returning a path relative to the project root."
  @spec asset_path(t(), Path.t()) :: Path.t()
  def asset_path(%__MODULE__{asset_root: root}, rel), do: Path.join(root, rel)

  @doc "Joins `rel` onto the generated-contracts directory (under the asset root)."
  @spec generated_path(t(), Path.t()) :: Path.t()
  def generated_path(%__MODULE__{asset_root: root, generated_dir: dir}, rel \\ "") do
    Path.join([root, dir, rel])
  end

  @doc "The Vite manifest path: the `:vite_manifest` build override, or the default under static_root."
  @spec manifest_path(t()) :: Path.t()
  def manifest_path(%__MODULE__{static_root: root, config: config}) do
    Keyword.get(config.build, :vite_manifest, Path.join(root, "assets/.vite/manifest.json"))
  end
end

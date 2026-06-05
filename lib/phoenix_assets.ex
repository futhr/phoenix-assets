defmodule PhoenixAssets do
  @moduledoc """
  Phoenix-native asset runtime and generated-contracts engine.

  `phoenix_assets` makes a modern JavaScript frontend first-class inside Phoenix
  without turning Phoenix into a bundler and without forcing LiveView/HEEx as the
  UI model. It supervises Vite and Storybook in development, generates typed
  frontend contracts from Phoenix and Ash, links routes / pages / stories / sync
  shapes / pubsub topics / locales into one asset graph, and validates the
  production manifest.

  This module is the public runtime facade. The heavy lifting lives in focused
  modules:

    * `PhoenixAssets.Config` -- normalized, validated configuration.
    * `PhoenixAssets.Preset` / `PhoenixAssets.Plugin` -- the integration engine.
    * `PhoenixAssets.Generated` -- the contract generators (routes, types, ...).
    * `PhoenixAssets.Manifest` / `PhoenixAssets.ManifestServer` -- Vite manifest.
    * `PhoenixAssets.Graph` -- the asset graph.
    * `PhoenixAssets.DevSupervisor` -- supervised dev processes.
    * `PhoenixAssets.Doctor` -- configuration and production validation.

  ## Why

  A Phoenix app that uses SvelteKit/Vite usually ends up as two loosely-coupled
  applications: Vite is not supervised, Storybook drifts, generated contracts are
  ad hoc, and frontend runtime errors are disconnected from Phoenix. This library
  gives Phoenix one explicit asset runtime and one graph so those seams close.
  """

  alias PhoenixAssets.{Config, Context, DevSupervisor, Graph, Manifest, ManifestServer}

  @doc """
  The OTP children assembled for the host application's supervision tree.

  Always includes the manifest server. The development supervisor (Vite,
  Storybook, the generated-file watcher) is added only when dev mode is enabled
  via `config :phoenix_assets, :dev, enabled: true`.

  Returns an empty list until those subsystems are wired in.
  """
  @spec children() :: [Supervisor.child_spec() | {module(), term()} | module()]
  def children, do: []

  @doc """
  The supervised children a host application adds to its own tree.

  Always includes `PhoenixAssets.ManifestServer`; in development also includes
  `PhoenixAssets.DevSupervisor` (Vite, Storybook, the generated-file watcher).
  Add them in your `Application.start/2`:

      children = [
        # ... your children ...
      ] ++ PhoenixAssets.child_specs()

  Options:

    * `:config` -- a `PhoenixAssets.Config` (defaults to `Config.load!/0`).
    * `:ctx` -- a prebuilt `PhoenixAssets.Context` (defaults to one derived from
      the config and the configured preset).
  """
  @spec child_specs() :: [Supervisor.child_spec() | {module(), term()}]
  @spec child_specs(keyword()) :: [Supervisor.child_spec() | {module(), term()}]
  def child_specs(opts \\ []) do
    config = opts[:config] || Config.load!()
    base = [{ManifestServer, path: Keyword.get(config.build, :vite_manifest)}]

    if dev?() do
      ctx = opts[:ctx] || Context.new(config, env: :dev, plugins: Config.preset_plugins(config))
      base ++ [{DevSupervisor, ctx: ctx}]
    else
      base
    end
  end

  @doc """
  Whether development features (supervised Vite/Storybook, the dev overlay, the
  generated-file watcher) are active.

  Defaults to `false` so production never spawns dev processes. Enable with:

      config :phoenix_assets, :dev, enabled: true
  """
  @spec dev?() :: boolean()
  def dev? do
    :phoenix_assets
    |> Application.get_env(:dev, [])
    |> Keyword.get(:enabled, false)
  end

  @doc "The installed version of `phoenix_assets`."
  @spec version() :: String.t()
  def version do
    case Application.spec(:phoenix_assets, :vsn) do
      nil -> "0.0.0"
      vsn -> List.to_string(vsn)
    end
  end

  @doc """
  Resolves an entry to its production assets, or `:dev` in development.

  In production returns `%{file:, css:, imports:, integrity:}` from the Vite
  manifest (`integrity` is a possibly-empty `href => hash` map, populated only
  when the manifest carries SRI metadata). In development returns `:dev` so
  callers emit dev-server URLs. Raises if a manifest is expected but unavailable.
  """
  @spec entry!(String.t()) ::
          %{
            file: String.t(),
            css: [String.t()],
            imports: [String.t()],
            integrity: %{String.t() => String.t()}
          }
          | :dev
  def entry!(key) do
    case ManifestServer.manifest() do
      :dev ->
        :dev

      {:error, reason} ->
        raise "phoenix_assets: Vite manifest unavailable (#{inspect(reason)}). Run `mix assets.build`."

      manifest ->
        %{
          file: Manifest.file(manifest, key),
          css: Manifest.css(manifest, key),
          imports: Manifest.imports(manifest, key),
          integrity: Manifest.subresource_integrity(manifest, key)
        }
    end
  end

  @doc """
  Returns the served path for an asset key.

  In production resolves to the hashed file from the manifest; otherwise returns
  the key as a root-relative path (the Vite dev server serves it).
  """
  @spec asset_path(String.t()) :: String.t()
  def asset_path(key) do
    case ManifestServer.manifest() do
      manifest when is_map(manifest) -> Manifest.file(manifest, key)
      _ -> "/" <> String.trim_leading(key, "/")
    end
  end

  @doc "Builds a Vite dev-server URL for `path` from the configured dev host/port."
  @spec vite_dev_url(String.t()) :: String.t()
  def vite_dev_url(path) do
    vite = Application.get_env(:phoenix_assets, :dev, [])[:vite] || []
    host = Keyword.get(vite, :host, "127.0.0.1")
    port = Keyword.get(vite, :port, 5173)
    "http://#{host}:#{port}/#{String.trim_leading(path, "/")}"
  end

  @doc """
  Loads the asset graph (`graph.json`), or an empty map if none has been built.

  For hot paths, prefer a module built with `PhoenixAssets.Graph.Compiled`.
  """
  @spec graph() :: map()
  def graph do
    case Graph.load(Context.new(Config.load!())) do
      {:ok, graph} -> graph
      _ -> %{}
    end
  end

  @doc "Fetches a page from the asset graph by name, raising if absent."
  @spec page!(String.t()) :: map()
  def page!(name), do: fetch_graph!("pages", name)

  @doc "Fetches a route from the asset graph by name, raising if absent."
  @spec route!(String.t()) :: map()
  def route!(name), do: fetch_graph!("routes", name)

  defp fetch_graph!(section, name) do
    case get_in(graph(), [section, name]) do
      nil -> raise KeyError, key: name, term: "asset graph #{section}"
      value -> value
    end
  end
end

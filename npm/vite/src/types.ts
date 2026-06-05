export interface PhoenixAssetsOptions {
  /** "app" (default), "storybook", or "test" — adjusts which behaviours are active. */
  mode?: "app" | "storybook" | "test"
  /** Directory (relative to the Vite root) where Elixir writes generated TS contracts. */
  generatedDir?: string
  /** Directory holding the generated locales.json (re-exported by $phoenix/localize). */
  localesDir?: string
  /** Gettext directory whose .po files the PO loader transforms. */
  gettextDir?: string
  /** Output path for the build-time asset graph (only when emitGraph is true). */
  graphOut?: string
  /** Emit graph.json from the Vite bundle at build time. Off by default; the
   *  canonical graph is built by `mix phoenix_assets.graph`. */
  emitGraph?: boolean
  /** Enable the dev HMR bridge (default: only when Vite is serving). */
  devClient?: boolean
  /** Virtual-module prefix (default "$phoenix"). */
  virtualPrefix?: string
}

export interface ResolvedOptions {
  mode: "app" | "storybook" | "test"
  root: string
  generatedDir: string
  localesDir: string
  gettextDir: string
  graphOut: string
  emitGraph: boolean
  devClient: boolean
  virtualPrefix: string
}

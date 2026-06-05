import type { ResolvedConfig } from "vite"
import type { PhoenixAssetsOptions, ResolvedOptions } from "./types"

export function resolveOptions(
  opts: PhoenixAssetsOptions,
  config: ResolvedConfig,
): ResolvedOptions {
  const mode = opts.mode ?? "app"

  return {
    mode,
    root: config.root,
    generatedDir: opts.generatedDir ?? "src/generated",
    localesDir: opts.localesDir ?? "src/lib/generated",
    gettextDir: opts.gettextDir ?? "../priv/gettext",
    graphOut: opts.graphOut ?? "../priv/static/assets/.phoenix-assets/graph.json",
    emitGraph: opts.emitGraph ?? false,
    devClient: opts.devClient ?? config.command === "serve",
    virtualPrefix: opts.virtualPrefix ?? "$phoenix",
  }
}

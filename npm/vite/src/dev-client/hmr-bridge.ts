import path from "node:path"
import { createFilter, type Plugin, type ViteDevServer } from "vite"
import { GENERATED, RESOLVED_PREFIX } from "../generated"
import { resolveOptions } from "../options"
import type { PhoenixAssetsOptions, ResolvedOptions } from "../types"

/**
 * Bridges Elixir-generated contract changes into Vite's HMR graph.
 *
 * Watches the generated directory (and the locales file) and, on change,
 * invalidates the affected on-disk module plus the `$phoenix/*` virtual modules
 * that re-export it, then triggers a reload. The plugin never writes generated
 * files (only Elixir does), so there is no feedback loop.
 */
export function devClientPlugin(opts: PhoenixAssetsOptions): Plugin {
  let options: ResolvedOptions

  return {
    name: "phoenix-assets:dev-client",
    apply: "serve",
    configResolved(config) {
      options = resolveOptions(opts, config)
    },
    configureServer(server) {
      if (!options.devClient) return

      const generated = path.resolve(options.root, options.generatedDir)
      const locales = path.resolve(options.root, options.localesDir, "locales.json")
      const filter = createFilter([`${generated}/**`, locales])
      const handle = (file: string) => invalidate(server, file, filter)

      server.watcher.on("change", handle)
      server.watcher.on("add", handle)
    },
  }
}

function invalidate(server: ViteDevServer, file: string, filter: (id: string) => boolean) {
  if (!filter(file)) return

  const modules = server.moduleGraph.getModulesByFile(file)
  if (modules) for (const mod of modules) server.moduleGraph.invalidateModule(mod)

  for (const name of Object.keys(GENERATED)) {
    const virtual = server.moduleGraph.getModuleById(RESOLVED_PREFIX + name)
    if (virtual) server.moduleGraph.invalidateModule(virtual)
  }

  server.ws.send({ type: "full-reload" })
}

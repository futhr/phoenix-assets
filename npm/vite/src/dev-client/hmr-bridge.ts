import path from "node:path"
import { createFilter, type Plugin } from "vite"
import { GENERATED, RESOLVED_PREFIX } from "../generated"
import { resolveOptions } from "../options"
import type { PhoenixAssetsOptions, ResolvedOptions } from "../types"

/**
 * Bridges Elixir-generated contract changes into Vite's HMR graph.
 *
 * Watches the generated directory (and the locales file) and, on change/add/unlink,
 * invalidates only the `$phoenix/*` virtual module backed by the changed file plus
 * the on-disk module itself, then triggers a reload. Events are debounced because
 * `mix phoenix_assets.gen` rewrites several files back-to-back. The plugin never
 * writes generated files (only Elixir does), so there is no feedback loop.
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

      // Backing file (absolute) -> virtual-module name, so a change touches one module.
      const fileToName = new Map<string, string>()
      for (const [name, entry] of Object.entries(GENERATED)) {
        fileToName.set(path.resolve(generated, entry.file), name)
      }

      const pending = new Set<string>()
      let timer: ReturnType<typeof setTimeout> | undefined

      const flush = () => {
        timer = undefined
        const files = [...pending]
        pending.clear()
        if (files.length === 0) return

        for (const file of files) {
          const name = fileToName.get(file)
          if (name) {
            const virtual = server.moduleGraph.getModuleById(RESOLVED_PREFIX + name)
            if (virtual) server.moduleGraph.invalidateModule(virtual)
          }
          const modules = server.moduleGraph.getModulesByFile(file)
          if (modules) for (const mod of modules) server.moduleGraph.invalidateModule(mod)
        }

        server.ws.send({ type: "full-reload" })
      }

      const handle = (file: string) => {
        if (!filter(file)) return
        pending.add(file)
        if (timer) clearTimeout(timer)
        timer = setTimeout(flush, 75)
      }

      server.watcher.on("change", handle)
      server.watcher.on("add", handle)
      server.watcher.on("unlink", handle)
    },
  }
}

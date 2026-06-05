import fs from "node:fs"
import path from "node:path"
import type { Plugin } from "vite"
import { resolveOptions } from "./options"
import type { PhoenixAssetsOptions, ResolvedOptions } from "./types"

/**
 * Optionally emits a build-time asset graph from the Vite bundle.
 *
 * Off by default: the canonical graph is built by `mix phoenix_assets.graph`,
 * which merges the Vite manifest with plugin-contributed entries. Enable
 * `emitGraph` for apps that prefer the JS side to write `graph.json` directly.
 */
export function graphEmitterPlugin(opts: PhoenixAssetsOptions): Plugin {
  let options: ResolvedOptions

  return {
    name: "phoenix-assets:graph-emitter",
    apply: "build",
    configResolved(config) {
      options = resolveOptions(opts, config)
    },
    writeBundle(_outputOptions, bundle) {
      if (!options.emitGraph) return

      const entries: Record<string, unknown> = {}
      for (const [fileName, chunk] of Object.entries(bundle)) {
        if (chunk.type === "chunk" && chunk.isEntry) {
          entries[chunk.name] = { file: `/${fileName}`, imports: chunk.imports.map((i) => `/${i}`) }
        }
      }

      const graph = { version: 1, generatedBy: "@phoenix-assets/vite", entries }
      const out = path.resolve(options.root, options.graphOut)
      fs.mkdirSync(path.dirname(out), { recursive: true })
      fs.writeFileSync(out, `${JSON.stringify(graph, null, 2)}\n`)
    },
  }
}

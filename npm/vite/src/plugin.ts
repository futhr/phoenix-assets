import type { Plugin } from "vite"
import { devClientPlugin } from "./dev-client/hmr-bridge"
import { graphEmitterPlugin } from "./graph-emitter"
import { poLoaderPlugin } from "./po-loader"
import type { PhoenixAssetsOptions } from "./types"
import { virtualModulesPlugin } from "./virtual-modules"

/**
 * The phoenix_assets Vite plugin: composes the virtual-module resolver, the PO
 * loader, the dev HMR bridge, and the (opt-in) graph emitter. Returns an array
 * so each sub-plugin can set its own `enforce`/`apply`, mirroring how
 * `@tailwindcss/vite` and `@sveltejs/kit` ship plugin arrays.
 */
export function phoenixAssets(opts: PhoenixAssetsOptions = {}): Plugin[] {
  return [
    virtualModulesPlugin(opts),
    poLoaderPlugin(),
    devClientPlugin(opts),
    graphEmitterPlugin(opts),
  ]
}

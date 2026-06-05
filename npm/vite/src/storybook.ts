import type { UserConfig } from "vite"
import { phoenixAssets } from "./plugin"
import type { PhoenixAssetsOptions } from "./types"

/**
 * A Vite config fragment for Storybook's `viteFinal`, so `$phoenix/*` and `.po`
 * resolution work identically inside Storybook and the app -- one source of
 * truth for the plugin across both.
 *
 *     // .storybook/main.ts
 *     async viteFinal(config) {
 *       return mergeConfig(config, createPhoenixViteConfig("storybook"))
 *     }
 */
export function createPhoenixViteConfig(
  mode: "storybook" | "app" = "storybook",
  opts: PhoenixAssetsOptions = {},
): UserConfig {
  return { plugins: phoenixAssets({ ...opts, mode }) }
}

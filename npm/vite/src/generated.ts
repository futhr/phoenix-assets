/** Prefix marking a resolved virtual module so Vite/Rolldown skips disk resolution. */
export const RESOLVED_PREFIX = "\0phoenix-assets:"

/** Virtual-module name -> generated file (relative to the generated dir). */
export const GENERATED: Record<string, string> = {
  routes: "routes.ts",
  env: "env.ts",
  types: "types.ts",
  electric: "electric.ts",
  pubsub: "pubsub.ts",
  localize: "locales.ts",
}

/**
 * Typed stubs returned when a generated file does not yet exist (the generated
 * directory is gitignored, so a fresh checkout boots before the first
 * `mix phoenix_assets.gen`).
 */
export const STUBS: Record<string, string> = {
  routes: "export const routes = {} as Record<string, never>\nexport type RouteName = never\n",
  env: "export const env = {} as Record<string, never>\n",
  types: "export {}\n",
  electric: "export const shapes = {} as Record<string, never>\n",
  pubsub: "export const topics = {} as Record<string, never>\nexport type PubSubEvent = never\n",
  localize:
    'export const locales = [] as const\nexport type Locale = string\nexport const defaultLocale = "en"\n',
}

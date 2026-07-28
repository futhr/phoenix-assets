/** Prefix marking a resolved virtual module so Vite/Rolldown skips disk resolution. */
export const RESOLVED_PREFIX = "\0phoenix-assets:"

interface GeneratedModule {
  /** Generated file, relative to the generated dir. */
  file: string
  /**
   * Typed stub returned when the generated file does not yet exist (the generated
   * directory is gitignored, so a fresh checkout boots before the first
   * `mix phoenix_assets.gen`).
   */
  stub: string
}

/** Virtual-module name -> generated file and its fallback stub, kept in sync by type. */
export const GENERATED = {
  routes: {
    file: "routes.ts",
    stub: "export const routes = {} as Record<string, never>\nexport type RouteName = never\n",
  },
  env: {
    file: "env.ts",
    stub: "export const env = {} as Record<string, never>\n",
  },
  types: {
    file: "types.ts",
    stub: "export {}\n",
  },
  electric: {
    file: "electric.ts",
    stub: "export const shapes = {} as Record<string, never>\n",
  },
  pubsub: {
    file: "pubsub.ts",
    stub: "export const topics = {} as Record<string, never>\nexport type PubSubEvent = never\n",
  },
  localize: {
    file: "locales.ts",
    stub: 'export const locales = [] as const\nexport type Locale = string\nexport const defaultLocale = "en"\n',
  },
  locales: {
    file: "locales.ts",
    stub: 'export const locales = [] as const\nexport type Locale = string\nexport const defaultLocale = "en"\n',
  },
} satisfies Record<string, GeneratedModule>

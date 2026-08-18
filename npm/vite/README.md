# @phoenix-assets/vite

The Vite half of [`phoenix_assets`](https://github.com/futhr/phoenix-assets). It
exposes the contracts Elixir generates as `$phoenix/*` virtual modules, bridges
HMR so a regenerated contract reloads without a restart, loads gettext `.po`
files, and emits the asset graph the Phoenix side validates against.

## Install

```bash
pnpm add -D @phoenix-assets/vite
```

`vite` is a peer (`^8.0.0`).

## Use

```ts
// vite.config.ts
import { phoenixAssets } from "@phoenix-assets/vite"
import { defineConfig } from "vite"

export default defineConfig({
  plugins: [phoenixAssets()],
})
```

That gives you:

```ts
import { routes } from "$phoenix/routes"
import { shapes } from "$phoenix/electric"
import type { Article } from "$phoenix/types"
```

The virtual modules resolve to whatever `mix phoenix_assets.gen` last wrote, so
the types cannot drift from the backend that produced them.

## Exports

| Export | What it is |
|---|---|
| `phoenixAssets` (also the default) | the plugin; `PhoenixAssetsOptions` types its options |
| `poLoader` | standalone gettext `.po` loader, if you want it without the rest |
| `createPhoenixViteConfig` | builds the Vite config Storybook shares with the app |

## Notes

Options default to the same paths the Elixir side uses, so an app following the
conventions passes nothing. Two worth knowing:

- `generatedDir` must agree with `config :phoenix_assets, generated_dir:`. Move
  one without the other and the virtual modules resolve to nothing.
- `mode` defaults to `"app"`, which is the only mode with the dev HMR bridge and
  the build-time graph emitter. Storybook gets `"storybook"` (via
  `createPhoenixViteConfig`) and test runners `"test"`; both keep the virtual
  modules and the PO loader and drop the rest.

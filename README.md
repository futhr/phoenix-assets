# Phoenix Assets

> Supervised SvelteKit tooling and typed frontend contracts for Phoenix.

[![CI](https://github.com/futhr/phoenix_assets/actions/workflows/ci.yml/badge.svg)](https://github.com/futhr/phoenix_assets/actions/workflows/ci.yml) [![codecov](https://codecov.io/gh/futhr/phoenix_assets/branch/main/graph/badge.svg)](https://codecov.io/gh/futhr/phoenix_assets) [![License: MIT](https://img.shields.io/github/license/futhr/phoenix_assets)](https://opensource.org/licenses/MIT)

---

Phoenix and a real JS frontend usually grow into two apps that barely know each
other: Vite runs unsupervised, Storybook drifts out of sync, the contracts
between backend and frontend get hand-copied, and an error on one side is
invisible to the other. `phoenix_assets` closes those seams. It supervises Vite
and Storybook as real children of your app, generates typed TypeScript from your
routes, Ash resources, Electric shapes, PubSub topics, and locales, and links
the whole thing into one asset graph it can validate before you ship.

It is **unapologetically opinionated, and that's the point.** Instead of trying
to support every framework under the sun, it commits to one stack and wires it
together so there's nothing left to assemble. That's the exact stack every one
of my Phoenix platforms runs — so it's built for those first, and it's MIT and
yours if you run the same one.

```
Phoenix         lifecycle, routes, auth, generated contracts, dev supervision, the asset graph
Vite            JS / TS / Svelte compilation, HMR, production bundles
SvelteKit       components, hydration, client routing
Storybook       isolated component development (shares Vite's config)
phoenix_assets  ties it together — one graph, one supervisor, one set of contracts
```

All composed into the default `PhoenixAssets.Presets.Svelte`.

---

## Depth, not just a bundler

A modern asset pipeline isn't "we run a bundler." The baseline the JavaScript
world expects — Laravel Vite, vite-ruby, Vite itself — is a pipeline that reads a
build manifest, emits correct hashed `<script>`/`<link>` tags with the production
niceties (CSP nonces, Subresource Integrity, module preloading), and keeps dev
and prod in sync. `phoenix_assets` does all of that, and goes deeper — because
Phoenix knows things a PHP or Ruby app never will at build time:

- **Typed contracts from five sources of truth.** Routes, Ash resources,
  ElectricSQL shapes, Phoenix.PubSub topics, and gettext locales are generated to
  TypeScript and exposed as `$phoenix/*` virtual modules. The types come from the
  backend, so they can't drift — and `mix phoenix_assets.gen --check` fails CI
  when the checked-in output is stale.
- **One asset graph.** Routes, pages, stories, sync shapes, topics, and locales
  link into a single validated graph (`graph.json`, or an embedded
  module) the app can query and the doctor can validate.
- **Supervised, not unsupervised.** Vite and Storybook run as real OTP children
  (MuonTrap kills the OS process when the BEAM exits; on Linux, cgroups tear down
  the whole process tree, on macOS the immediate child) with status/logs/restart
  introspection — not a detached `npm run dev` that silently dies.
- **Deterministic, content-gated generation.** Generators emit byte-identical
  output for identical inputs; a regeneration that changes nothing writes nothing
  and triggers no HMR. That contract is what makes the no-write fast path and the
  drift check meaningful.
- **A production doctor.** `mix phoenix_assets.doctor --production` validates the
  manifest, the package manager, contract freshness, and per-integration
  invariants before you ship.
- **Telemetry throughout.** Every long-running operation emits `:telemetry` spans
  under `[:phoenix_assets, ...]` — `:generated`, `:manifest`, `:dev_server`,
  `:doctor` — so host observability stacks have a stable surface to attach to.

That's the difference between wiring a bundler into a framework and making the
frontend observable and type-checked from the Phoenix application.

---

## How it fits together

**Vite, SvelteKit, and Storybook are supervised as one unit.**
`PhoenixAssets.child_specs/0` adds the manifest server (always) and, in
development, a supervisor that owns Vite, Storybook, and the generated-file
watcher. Storybook shares Vite's config, so the two never drift.

**Tailwind v4 runs inside Vite** through the official `@tailwindcss/vite` plugin
— CSS-first, no JS config; you own `src/app.css` and its `@theme`. The
integration wires the plugin into the Vite config and contributes a doctor check
that the CSS entry exists, so the asset graph stays honest about what produces
your CSS. `@phoenix-assets/lint` adds a Tailwind v4 linter that flags arbitrary
values like `w-[180px]` when a named equivalent (`w-45`) exists — checked against
your *real* design system.

**The frontend imports generated contracts directly** through `$phoenix/*`
virtual modules, and HMR is bridged: when Elixir regenerates a contract, the Vite
plugin invalidates the affected modules and reloads — no manual restart, no stale
types.

---

## Packages

One Elixir package ships the runtime, the (internal) plugin engine, and the
built-in Svelte stack. Three npm packages provide the Vite plugin, the Svelte
runtime helpers, and shared frontend lint tooling.

| Package | Path | What it is |
|---------|------|------------|
| `phoenix_assets` | `lib/` | Runtime + generated-contracts engine, dev supervision, manifest, graph, doctor, and the built-in SvelteKit + Tailwind + Storybook + ElectricSQL + PubSub + localization + Ash-types stack. Hex. |
| `@phoenix-assets/vite` | `npm/vite/` | Vite plugin, `$phoenix/*` virtual modules, dev/HMR bridge, graph emitter. npm. |
| `@phoenix-assets/svelte` | `npm/svelte/` | Typed Electric / PubSub / localization helpers plus the closed portable-report decoder, accessible tables, and shared LayerChart 2 components. npm. |
| `@phoenix-assets/lint` | `npm/lint/` | Shared Biome base config + Tailwind v4 arbitrary-value linter for host apps. npm. |

---

## Requirements

- Elixir 1.18+ and Phoenix 1.8+.
- Development supervision (Vite and Storybook as OS children, torn down with the
  BEAM — the whole process tree via Linux cgroups, the immediate child on macOS)
  requires a POSIX platform — macOS, Linux, or WSL2 — via MuonTrap. Production
  manifest serving and contract generation are platform-independent.

---

## Usage

> Runs in production on the author's platforms. Installed directly from GitHub.

The full Svelte stack is the default — there's no preset module to write.

### Install

```elixir
# mix.exs
{:phoenix_assets, github: "futhr/phoenix_assets"}
```

```bash
cd assets && pnpm add -D @phoenix-assets/vite @phoenix-assets/svelte @phoenix-assets/lint
```

### Configure & supervise

```elixir
# config/config.exs
config :phoenix_assets,
  otp_app: :my_app,
  endpoint: MyAppWeb.Endpoint,
  router: MyAppWeb.Router

config :phoenix_assets, :stack,
  shapes: MyApp.Assets.ElectricShapes,
  topics: MyApp.Assets.PubSubTopics,
  types: MyApp.Assets.Types

# config/dev.exs — supervise Vite, Storybook, and the generated-file watcher
config :phoenix_assets, :dev, enabled: true
```

Add the runtime to your supervision tree — `child_specs/0` returns the manifest
server always, plus the dev supervisor in development:

```elixir
children = [...] ++ PhoenixAssets.child_specs()
```

`:otp_app` is the only required option; the full reference is `PhoenixAssets.Config`.
Sub-configs: `:dev`, `:build` (`vite_manifest`, `asset_graph`, `asset_url`,
`budgets`, `allow_source_maps`), `:env` (`expose:`), and `:stack`.

### Declare & generate contracts

Declare your backend contracts — metadata only; the real work (Ash queries,
policies, tenancy) stays in your controllers:

```elixir
defmodule MyApp.Assets.ElectricShapes do
  use PhoenixAssets.Electric.Shapes
  shape :articles, route: "/shapes/articles", type: "Article"
end

defmodule MyApp.Assets.PubSubTopics do
  use PhoenixAssets.PubSub.Topics
  topic :room, pattern: "room:{id}", events: [message: "Message"]
end

defmodule MyApp.Assets.Types do
  use PhoenixAssets.Types.Schema
  type "Article", resource: MyApp.Blog.Article, only: :public
end
```

```bash
mix phoenix_assets.gen          # write assets/src/generated/*
mix phoenix_assets.gen --check  # CI drift gate; fails when the checked-in output is stale
```

Import the typed output through `$phoenix/*` virtual modules. Sensitive and
non-public Ash fields never reach a generated type, and page routes are
SvelteKit's — never generated:

```ts
import { routes } from "$phoenix/routes"
import type { Article } from "$phoenix/types"
import { shapes } from "$phoenix/electric"
```

Portable report consumers import only the shared reporting boundary. It accepts
the bounded renderer-neutral contract, rejects unknown or renderer-specific
configuration, and always preserves a semantic table representation:

```svelte
<script lang="ts">
  import { decodeReportEnvelope, PortableReport } from "@phoenix-assets/svelte/reporting"

  let { payload } = $props()
  const envelope = decodeReportEnvelope(payload)
</script>

<PortableReport {envelope} />
```

`layerchart` is an internal exact dependency of this subpath. Host applications
must not pass LayerChart options through storage/network data or install another
generic chart stack for portable report kinds. Hosts supply semantic CSS tokens,
localized chrome, and domain evidence around the shared components.

### Render assets

```heex
<PhoenixAssets.Components.vite_assets entry="src/app.ts" nonce={@csp_nonce} />
<PhoenixAssets.Components.svelte_page name="Dashboard" props={%{user: @user}} />
```

In development these point at the Vite dev server; in production they emit the
hashed file with its stylesheet links, module preloads, and Subresource Integrity
from the manifest. Set `config :phoenix_assets, :build, asset_url:` for a CDN, or
add `plug PhoenixAssets.EarlyHints, entry: "src/app.ts"` for HTTP 103 Early Hints.

### Ship

Wire the drift gate and the production doctor into your deploy alias:

```elixir
# mix.exs
"assets.deploy": ["phoenix_assets.gen --check", "phoenix_assets.doctor --production", ...]
```

`doctor --production` validates the manifest, contract freshness, bundle budgets,
source-map leakage, and that every plugin initialises. Every long-running
operation emits `:telemetry` under `[:phoenix_assets, ...]` — see
`PhoenixAssets.Telemetry`.

### A different stack

Write a module with `use PhoenixAssets.Preset`, list your `integration/2` calls,
and set it as `:preset` (copy `PhoenixAssets.Presets.Svelte` as a starting point).
Add an integration the stack doesn't ship by writing a `use PhoenixAssets.Plugin`
module.

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](https://github.com/futhr/phoenix_assets/blob/main/CONTRIBUTING.md) for guidelines.

---

## License

Phoenix Assets is released under the MIT License. See [LICENSE](https://github.com/futhr/phoenix_assets/blob/main/LICENSE) for details.

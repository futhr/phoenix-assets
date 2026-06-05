# Phoenix Assets

> A modern JavaScript frontend, first-class inside Phoenix — without turning Phoenix into a bundler or living in HEEx.

[![Hex.pm](https://img.shields.io/hexpm/v/phoenix_assets.svg)](https://hex.pm/packages/phoenix_assets) [![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/phoenix_assets) [![CI](https://github.com/futhr/phoenix_assets/actions/workflows/ci.yml/badge.svg)](https://github.com/futhr/phoenix_assets/actions/workflows/ci.yml) [![codecov](https://codecov.io/gh/futhr/phoenix_assets/branch/main/graph/badge.svg)](https://codecov.io/gh/futhr/phoenix_assets) [![License: MIT](https://img.shields.io/github/license/futhr/phoenix_assets)](https://opensource.org/licenses/MIT)

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
  link into a single validated graph (`graph.json`, or a zero-cost compiled
  module) the app can query and the doctor can validate.
- **Supervised, not unsupervised.** Vite and Storybook run as real OTP children
  (MuonTrap, with OS process-group cleanup) with status/logs/restart
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
frontend a first-class, observable, type-checked part of the application.

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

**The frontend imports generated contracts directly:**

```ts
import { routes } from "$phoenix/routes"
import type { Portfolio } from "$phoenix/types"
import { shapes } from "$phoenix/electric"
import { topics } from "$phoenix/pubsub"
```

HMR is bridged: when Elixir regenerates a contract, the Vite plugin invalidates
the affected virtual modules and reloads — no manual restart, no stale types.

---

## Packages

One Elixir package ships the runtime, the (internal) plugin engine, and the
built-in Svelte stack. Three npm packages provide the Vite plugin, the Svelte
runtime helpers, and shared frontend lint tooling.

| Package | Path | What it is |
|---------|------|------------|
| `phoenix_assets` | `lib/` | Runtime + generated-contracts engine, dev supervision, manifest, graph, doctor, and the built-in SvelteKit + Tailwind + Storybook + ElectricSQL + PubSub + localization + Ash-types stack. Hex. |
| `@phoenix-assets/vite` | `npm/vite/` | Vite plugin, `$phoenix/*` virtual modules, dev/HMR bridge, graph emitter. npm. |
| `@phoenix-assets/svelte` | `npm/svelte/` | Typed Electric / PubSub / localization runtime helpers. npm. |
| `@phoenix-assets/lint` | `npm/lint/` | Shared Biome base config + Tailwind v4 arbitrary-value linter for host apps. npm. |

---

## Usage

> **Runs in production on the author's platforms.** Install from GitHub; a Hex
> release is pending.

The full Svelte stack is the default — there's no preset module to write. Add the
dependency, point Phoenix at it, and name your declaration modules:

```elixir
# mix.exs
{:phoenix_assets, github: "futhr/phoenix_assets"}

# config/config.exs
config :phoenix_assets,
  otp_app: :my_app,
  endpoint: MyAppWeb.Endpoint,
  router: MyAppWeb.Router

config :phoenix_assets, :stack,
  shapes: MyApp.Assets.ElectricShapes,
  topics: MyApp.Assets.PubSubTopics,
  types: MyApp.Assets.Types
```

Want a different mix? Write a module with `use PhoenixAssets.Preset` and set it
as `:preset` — copy `PhoenixAssets.Presets.Svelte` as your starting point.

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

Phoenix Assets is released under the MIT License. See [LICENSE](LICENSE) for details.

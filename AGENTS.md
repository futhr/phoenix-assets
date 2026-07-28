# AGENTS.md

Guidance for AI coding agents working **on** `phoenix_assets`. For using the
library in a host app, see [`usage-rules.md`](usage-rules.md).

## What this repo is

One Elixir Hex package (`:phoenix_assets`, at the repo root) plus four npm packages
in a pnpm workspace (`npm/vite`, `npm/svelte`, `npm/doc-shell`, `npm/lint`). The
Elixir side is a plugin/preset engine + generators + dev supervision; the npm side
is the Vite plugin, the Svelte runtime helpers, the documentation shell, and the
shared frontend lint tooling. Everything lives under the `PhoenixAssets.*`
namespace.

## Setup

```bash
mix deps.get
pnpm install
```

The dev toolchain is pinned in `.tool-versions` (Erlang/OTP 28, Elixir 1.19,
Node 24); pnpm for the frontend. Consumers only need the `mix.exs` floor —
Elixir `~> 1.18`. CI proves both ends of that range: a floor leg on Elixir
1.18/OTP 27 (compile + ExUnit only) and the full gate on 1.20/OTP 29.

## The one command that matters

```bash
mix check
```

`mix check` is the single quality gate for the **whole repo** and must stay green.
It runs: `compile --warnings-as-errors`, `format --check-formatted`,
`credo --strict`, `doctor` (doc coverage), `mix_audit`, `dialyzer`, ExUnit **with
coverage** (`mix coveralls.lcov`, ≥85%), and the frontend — Biome (strict),
`tsc --noEmit`, Vitest **with coverage** (≥80%), knip (dead-code detection),
`check:exports` (publint + arethetypeswrong), and the scope gate
(`scripts/check-boundary.mjs`, see below). It therefore requires Node + pnpm on
PATH. Config lives in `.check.exs`, `.doctor.exs`, `coveralls.json`, `.credo.exs`,
`biome.json`, `knip.json`.

Useful narrower commands: `mix test`, `MIX_ENV=test mix coveralls.html`,
`mix doctor`, `mix format`, `pnpm -r test`, `pnpm lint`, `pnpm -r typecheck`.

## Structure

```
lib/phoenix_assets/        engine (Plugin/Preset/Resolver/Engine), Config/Context,
                           generators, Graph, Manifest, Doctor, Dev*, the 9 stack
                           plugins and their declaration DSLs, Presets.Svelte
lib/mix/tasks/             phoenix_assets.install/.gen/.doctor/.clean/.graph, plus
                           eight gen.<contract> delegates that forward to gen --only
test/                      ExUnit; test/support holds Ash fixtures; the headline
                           test is test/phoenix_assets/integration/kitchen_sink_test.exs
npm/vite, npm/svelte       TypeScript packages (Biome + Vitest)
npm/doc-shell              Svelte documentation UI for the doc-shell/v1 contract
npm/lint                   shared Biome base config + Tailwind v4 linter for host apps
```

## What may live here

`phoenix_assets` is a **generic, UI-free asset substrate**. It may know about
Phoenix, Vite, Svelte, Tailwind, Electric, and Ash. It may not know about any
product built on it. A feature belongs here only if it would read as sensible to
someone who has never seen the apps that consume it.

`@phoenix-assets/svelte/reporting` is the **one sanctioned UI exception**, and it
survives only on a specific guarantee: it decodes a *generic* versioned envelope
into generic charts. Domain semantics and theming come from the host. The moment
it can name a business concept, it has stopped being renderer-neutral and the
exception no longer applies. The contract it renders is owned upstream — changes
land there first, and this package follows.

`node scripts/check-boundary.mjs` enforces the mechanical half (no consuming
platform's name anywhere in `lib/` or `npm/*/src`; no business vocabulary inside
`reporting/`) and runs as part of `mix check`. The judgement half is yours: when
a host asks for something, the question is whether the *next* host would want the
same thing, or whether the seam is just too narrow for them to do it themselves.

Two failure modes to watch, because both have happened:

- **Absorbing a feature.** A host's product code arrives wearing a generic name.
  The gate catches the obvious version; the subtle version is a config key or a
  contract field that only one host will ever set.
- **Refusing to generalise.** More common here, and more expensive. A gap in this
  library gets paid for once per host — six of them rebuilt the same Electric
  shape store, four the same auth headers, three the same enum generator. If you
  find a host working around this library, that is a bug report about this
  library.

## Conventions & gotchas

- **Strict gates.** Warnings are errors; credo is `--strict`; unused variables must
  be a bare `_` (not `_foo`); dynamic atom creation is forbidden. Biome runs strict
  with `noUnusedImports/Variables/FunctionParameters` as errors.
- **Default preset.** `Config.preset_plugins/1` resolves `PhoenixAssets.Presets.Svelte`
  when `:preset` is unset. Stack plugins read host declaration modules from
  `config :phoenix_assets, :stack, ...`.
- **Optional deps.** All of `ash`, `ash_typescript`, `phoenix_sync`, `gettext`,
  `tidewave`, `phoenix_live_view`, `igniter` are `optional: true`, but only three
  have code behind them. `ash_typescript`, `phoenix_sync`, and `tidewave` are pure
  version pins — nothing in `lib/` references them, so there are no guards there to
  maintain. The ones that do carry code use two idioms: wrap the whole `defmodule`
  in `if Code.ensure_loaded?/1` (`components.ex` for `Phoenix.Component`,
  `phoenix_assets.install.ex` for Igniter), or gate at the call site (`types.ex`).
  Don't add hard deps on any of them.
- **The Ash guard is narrower than it looks.** `walker.ex` calls
  `Ash.Resource.Info` and `Ash.Type.short_names/0` with no guard of its own; it is
  safe only because `types.ex`'s `ash_available?/0` is its sole entry point. Both
  files compile with no Ash present, but giving `walker.ex` a second caller
  without a guard would break that.
- **Coverage floors:** Elixir 85% (`coveralls.json`; thin `gen.*` delegates
  skipped), frontend 80%. `npm/svelte/src/electric/shape-collection.ts`
  is excluded from coverage (TanStack svelte-db only resolves under browser/svelte
  conditions, not in a Node test runner).
- **Doc coverage.** `mix doctor` requires 100% moduledoc coverage; keep `@moduledoc`
  on every module and `@moduledoc false` on tests/fixtures.
- **Determinism.** Generators must emit byte-identical output for identical input
  (no timestamps, stable ordering) — the no-write fast path and `--check` drift gate
  depend on it.
- **Releases.** Conventional Commits drive `mix git_ops.release` (from the git root).
  Mark breaking changes with `!` (`feat!:`), never a `BREAKING CHANGE:` footer.
- **One package.** There is no `core/`/`stack/` split — don't reintroduce it. Both
  layers share the `PhoenixAssets.*` namespace in `lib/`.

## Definition of done

`mix check` is green end-to-end (Elixir + frontend + both coverage floors), and any
new public module has a `@moduledoc`.

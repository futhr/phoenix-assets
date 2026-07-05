# AGENTS.md

Guidance for AI coding agents working **on** `phoenix_assets`. For using the
library in a host app, see [`usage-rules.md`](usage-rules.md).

## What this repo is

One Elixir Hex package (`:phoenix_assets`, at the repo root) plus three npm packages
in a pnpm workspace (`npm/vite`, `npm/svelte`, `npm/lint`). The Elixir side is a
plugin/preset engine + generators + dev supervision; the npm side is the Vite
plugin, the Svelte runtime helpers, and the shared frontend lint tooling.
Everything lives under the `PhoenixAssets.*` namespace.

## Setup

```bash
mix deps.get
pnpm install
```

The dev toolchain is pinned in `.tool-versions` (Erlang/OTP 28, Elixir 1.19,
Node 24); pnpm for the frontend. Consumers only need the `mix.exs` floor —
Elixir `~> 1.18`.

## The one command that matters

```bash
mix check
```

`mix check` is the single quality gate for the **whole repo** and must stay green.
It runs: `compile --warnings-as-errors`, `format --check-formatted`,
`credo --strict`, `doctor` (doc coverage), `mix_audit`, `dialyzer`, ExUnit **with
coverage** (`mix coveralls.lcov`, ≥85%), and the frontend — Biome (strict),
`tsc --noEmit`, and Vitest **with coverage** (≥80%). It therefore requires Node +
pnpm on PATH. Config lives in `.check.exs`, `.doctor.exs`, `coveralls.json`,
`.credo.exs`, `biome.json`.

Useful narrower commands: `mix test`, `MIX_ENV=test mix coveralls.html`,
`mix doctor`, `mix format`, `pnpm -r test`, `pnpm lint`, `pnpm -r typecheck`.

## Structure

```
lib/phoenix_assets/        engine (Plugin/Preset/Resolver/Engine), Config/Context,
                           generators, Graph, Manifest, Doctor, Dev*, the 7 stack
                           plugins, Presets.Svelte
lib/mix/tasks/             phoenix_assets.gen/.doctor/.clean/.graph
test/                      ExUnit; test/support holds Ash fixtures; the headline
                           test is test/phoenix_assets/integration/kitchen_sink_test.exs
npm/vite, npm/svelte       TypeScript packages (Biome + Vitest)
npm/lint                   shared Biome base config + Tailwind v4 linter for host apps
```

## Conventions & gotchas

- **Strict gates.** Warnings are errors; credo is `--strict`; unused variables must
  be a bare `_` (not `_foo`); dynamic atom creation is forbidden. Biome runs strict
  with `noUnusedImports/Variables/FunctionParameters` as errors.
- **Default preset.** `Config.preset_plugins/1` resolves `PhoenixAssets.Presets.Svelte`
  when `:preset` is unset. Stack plugins read host declaration modules from
  `config :phoenix_assets, :stack, ...`.
- **Optional deps.** `ash`, `ash_typescript`, `phoenix_sync`, `gettext`, `tidewave`,
  `phoenix_live_view` are `optional: true`. Code must compile and run without them
  (guard Ash use behind `Code.ensure_loaded?/1`; `types.ex`/`walker.ex` must compile
  with no Ash present). Don't add hard deps on these.
- **Coverage floors:** Elixir 85% (`coveralls.json`, `application.ex` + thin
  `gen.*` delegates skipped), frontend 80%. `npm/svelte/src/electric/shape-collection.ts`
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

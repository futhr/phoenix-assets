# AGENTS.md

Guidance for coding agents working on `phoenix_assets`. For using the
library in a host app, see [`usage-rules.md`](usage-rules.md).

## What this repo is

The repository contains one Elixir Hex package (`:phoenix_assets`, at the root)
and four npm packages
in a pnpm workspace (`npm/vite`, `npm/svelte`, `npm/doc-shell`, `npm/lint`). The
Elixir side is a plugin/preset engine + generators + dev supervision; the npm side
is the Vite plugin, the Svelte runtime helpers, the documentation shell, and the
shared frontend lint tooling. Everything lives under the `PhoenixAssets.*`
namespace.

## Writing

Apply `.claude/skills/unslop/SKILL.md` to persisted prose and
`.claude/skills/phoenix-assets-evidence-voice/SKILL.md` to public documentation,
audits, release notes, and summaries. Preserve code, version numbers, measured
results, and contract language while making the surrounding prose direct and
human.

## Setup

```bash
mix deps.get
pnpm install
```

The dev toolchain is pinned in `.tool-versions` (Erlang/OTP 28, Elixir 1.19,
Node 24); pnpm for the frontend. Consumers only need the `mix.exs` floor:
Elixir `~> 1.18`. Local release qualification proves both ends: a floor leg on
Elixir 1.18/OTP 27 (compile + ExUnit) and the full gate on 1.20/OTP 29. Ordinary
PRs run one current-runtime lane; broad qualification runs locally.

## Quality gate

```bash
mix check
```

`mix check` is the quality gate for the whole repository and must stay green.
It runs: `compile --warnings-as-errors`, `format --check-formatted`,
`credo --strict`, `doctor` (doc coverage), `docs --warnings-as-errors`,
`mix deps.audit`, `mix hex.audit`, `dialyzer`, ExUnit with coverage
(`mix coveralls.lcov`, ≥85%), and the frontend checks: Biome (strict),
`tsc --noEmit`, Vitest with coverage (≥80%), knip (dead-code detection),
`check:exports` (publint + arethetypeswrong), and the scope gate
(`scripts/check-boundary.mjs`, see below). It also requires the npm production
security audit, release checks, and a minimal consumer of the built Hex tarball
with no optional dependencies. It therefore requires Node + pnpm on
PATH. Config lives in `.check.exs`, `.doctor.exs`, `coveralls.json`, `.credo.exs`,
`biome.json`, `knip.json`.

Useful narrower commands: `mix test`, `MIX_ENV=test mix coveralls.html`,
`mix doctor`, `mix format`, `pnpm -r test`, `pnpm lint`, `pnpm -r typecheck`.

## Structure

```
lib/phoenix_assets/        engine (Plugin/Preset/Resolver/Engine), Config/Context,
                           generators, Graph, Manifest, Doctor, Dev*, the 11 stack
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

`phoenix_assets` is a generic, UI-free asset substrate. It may know about
Phoenix, Vite, Svelte, Tailwind, Electric, and Ash. It may not know about any
product built on it. A feature belongs here only if it would read as sensible to
someone who has never seen the apps that consume it.

`@phoenix-assets/svelte/reporting` is the one UI exception. It decodes a generic
versioned envelope into generic charts. Domain semantics and theming come from the host. The moment
it can name a business concept, it has stopped being renderer-neutral and the
exception no longer applies. The contract it renders is owned upstream. Changes
land there first, and this package follows.

`node scripts/check-boundary.mjs` enforces the mechanical half (no consuming
platform's name anywhere in `lib/` or `npm/*/src`; no business vocabulary inside
`reporting/`) and runs as part of `mix check`. The judgement half is yours: when
a host asks for something, the question is whether the *next* host would want the
same thing, or whether the seam is just too narrow for them to do it themselves.

Two recurring failure modes need review:

- Absorbing a feature. A host's product code arrives with a generic name.
  The gate catches the obvious version; the subtle version is a config key or a
  contract field that only one host will ever set.
- Refusing to generalise. A gap in this library gets paid for once per host.
  Six of them rebuilt the same Electric
  shape store, four the same auth headers, three the same enum generator. If you
  find a host working around this library, that is a bug report about this
  library.

## Conventions

- Strict gates. Warnings are errors; Credo runs with `--strict`; unused variables must
  be a bare `_` (not `_foo`); dynamic atom creation is forbidden. Biome runs strict
  with `noUnusedImports/Variables/FunctionParameters` as errors.
- Default preset. `Config.preset_plugins/1` resolves `PhoenixAssets.Presets.Svelte`
  when `:preset` is unset. Stack plugins read host declaration modules from
  `config :phoenix_assets, :stack, ...`.
- Optional dependencies. All of `ash`, `ash_typescript`, `gettext`,
  `tidewave`, `phoenix_live_view`, `igniter` are `optional: true`, but only three
  have code behind them. `ash_typescript` and `tidewave` are pure
  version pins. Nothing in `lib/` references them, so there are no guards there to
  maintain. The ones that do carry code use two idioms: wrap the whole `defmodule`
  in `if Code.ensure_loaded?/1` (`components.ex` for `Phoenix.Component`,
  `phoenix_assets.install.ex` for Igniter), or gate at the call site (`types.ex`).
  Don't add hard deps on any of them.
- Sync qualification. Phoenix.Sync is a dev/test dependency at an immutable
  qualified revision. It must not appear in the published Hex requirements.
  Hosts select their backend; embedded hosts also own their Electric dependency.
  The Svelte peers require the qualified Electric/TanStack package floors.
- Optional dependency isolation. `types.ex` gates Ash generation and
  `walker.ex` guards its public entry points. Narrow compiler annotations cover
  references to optional modules only when those modules are absent. The
  `hex_consumer` check compiles the packaged library without any optional
  dependencies and verifies that this produces no Elixir compiler warnings.
- Coverage floors: Elixir 85% (`coveralls.json`; thin `gen.*` delegates
  skipped), frontend 80%. The collection regression uses the actual TanStack
  and Electric packages under the browser conditions in the Svelte test runner,
  with a controlled fetch transport; the collection helper is included in coverage.
- Documentation coverage. `mix doctor` requires 100% moduledoc coverage; keep `@moduledoc`
  on every module and `@moduledoc false` on tests/fixtures.
- Determinism. Generators must emit byte-identical output for identical input
  (no timestamps, stable ordering). The no-write fast path and `--check` drift gate
  depend on it.
- Releases. Conventional Commits drive `mix git_ops.release` from the Git root.
  Mark breaking changes with `!` (`feat!:`), never a `BREAKING CHANGE:` footer.
- Package layout. There is no `core/` or `stack/` split. Both
  layers share the `PhoenixAssets.*` namespace in `lib/`.

## Definition of done

`mix check` is green end-to-end (Elixir + frontend + both coverage floors), and any
new public module has a `@moduledoc`.

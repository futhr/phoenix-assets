# Contributing

Thanks for helping out. This repo is one Elixir package plus two npm packages
(`npm/vite`, `npm/svelte`) in a pnpm workspace.

## Setup

```bash
mix deps.get
pnpm install
```

Toolchain is pinned in `.tool-versions` (Erlang/OTP 28, Elixir 1.19); you'll also
need Node 22 + pnpm. The Elixir requirement for *consumers* is `~> 1.16`.

## The quality gate

One command runs everything — Elixir and frontend — and must pass before a PR
merges:

```bash
mix check
```

It runs compile (warnings as errors), formatter, `credo --strict`, `doctor`
(documentation coverage), `mix_audit`, `dialyzer`, ExUnit with coverage (≥85%),
and the frontend: Biome (strict lint+format), `tsc`, and Vitest with coverage
(≥80%). Because it drives the frontend tools, `mix check` needs Node + pnpm on
PATH. To auto-fix the cheap stuff first: `mix format` and `pnpm format`.

Coverage reports for local inspection: `MIX_ENV=test mix coveralls.html` (Elixir)
and `pnpm -r test` (frontend lcov under `npm/*/coverage/`).

## Conventions

- Public modules need a `@moduledoc`; tests and fixtures use `@moduledoc false`.
- Unused variables are a bare `_` (credo enforces it); no dynamic atom creation.
- Generators must emit byte-identical output for identical input (determinism).
- Keep `ash` and the other stack integrations **optional** — code must compile
  without them.

## Commits & releases

Commits follow [Conventional Commits](https://www.conventionalcommits.org)
(`feat:`, `fix:`, `docs:`, `chore:`, …); mark breaking changes with `!`
(`feat!: ...`), **not** a `BREAKING CHANGE:` footer (git_ops mis-parses it).
Releases are cut from the git root with:

```bash
mix git_ops.release   # --initial for the first release
```

## Pull requests

1. Branch from `main`.
2. Make the change; run `mix check` until green.
3. Open a PR explaining the *why*; reference issues (`Closes #123`).
4. CI runs `mix check` + the production build — it must be green to merge.

See [`AGENTS.md`](AGENTS.md) for a deeper map of the repo and its gotchas.

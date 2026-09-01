# @phoenix-assets/lint

The shared frontend lint tooling for `phoenix_assets` host apps (Svelte 5 +
Tailwind v4): a base **Biome** config, a Svelte structure linter, and the
**Tailwind v4 arbitrary-value linter**. Biome owns syntax and style. The focused
linters enforce project structure and design-system rules that Biome cannot
infer.

## Install

```bash
pnpm add -D @phoenix-assets/lint @biomejs/biome tailwindcss svelte
```

`@biomejs/biome`, `tailwindcss`, and `svelte` are peers (you already have them).

## Biome config

```jsonc
// biome.json
{ "extends": ["@phoenix-assets/lint/biome.base.json"] }
```

Layer your app-specific `files.includes` excludes and `overrides` on top (e.g.
barrel-file exemptions, your Tailwind entry CSS).

The base is deliberately laxer than the config `phoenix_assets` runs on itself:
unused imports and variables are warnings rather than errors, and the noisier
`suspicious` rules are off. A shared config that fails an app's build on day one
gets deleted, not adopted — so raise these in your own `biome.json` once the app
is clean. It is also *stricter* in one direction: the `performance` rules
(`noBarrelFile`, `noReExportAll`, `noAccumulatingSpread`) are errors, because
those cost host apps bundle size in a way they cannot see from a diff.

A `**/*.svelte` override disables `useConst`, `useImportType`,
`noUnusedVariables`, and `noUnusedImports` — Biome false-positives on all four in
Svelte files.

## Tailwind v4 linter

The package ships a compiled `phoenix-assets-lint-tailwind` binary (Node cannot
strip types for files under `node_modules`, so the linter is published as JS —
see the [Node type-stripping docs](https://nodejs.org/api/typescript.html)).

```jsonc
// package.json
{
  "scripts": {
    "lint:tw": "phoenix-assets-lint-tailwind"
  }
}
```

Or invoke it ad hoc with `pnpm exec phoenix-assets-lint-tailwind` /
`npx phoenix-assets-lint-tailwind`.

Run it from your frontend root — it reads `src/app.css` and scans
`src/**/*.svelte` + `src/**/*.variants.ts` by default (pass paths to override),
and exits non-zero on findings. CSS imports may use exact or trailing-wildcard
aliases from the host `svelte.config.js`. The resolver also supports SvelteKit's
implicit `$lib` alias and respects `kit.files.lib`; virtual aliases such as
`$app` and `$env` are intentionally outside a filesystem stylesheet resolver.
Bare package imports resolve from the importing stylesheet and host project, so
pnpm's strict dependency layout does not require packages to be dependencies of
the linter itself.
It uses Tailwind's `__unstable__loadDesignSystem` API, so keep it aligned with
your `tailwindcss` version.

## Svelte structure linter

`phoenix-assets-lint-svelte` parses every selected component with the Svelte
compiler. Module and instance script blocks may coexist: that is a standard
Svelte composition pattern. Hosts with a stricter local convention can opt in
to `--single-script` and add repeated `--allow <glob>` exceptions. Keeping the
policy explicit prevents a host convention from being mistaken for a Svelte
invariant.

```jsonc
{
  "scripts": {
    "lint:svelte": "phoenix-assets-lint-svelte",
    "lint:svelte:strict": "phoenix-assets-lint-svelte --single-script --allow 'src/**/*.stories.svelte'"
  }
}
```

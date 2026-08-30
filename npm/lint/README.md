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
and exits non-zero on findings. CSS imports may use aliases from the host
`svelte.config.js`; the linter resolves the same `kit.alias` map used by
SvelteKit. It uses Tailwind's `__unstable__loadDesignSystem` API, so keep it
aligned with your `tailwindcss` version.

## Svelte structure linter

`phoenix-assets-lint-svelte` rejects files containing both module and instance
script blocks. Keeping one script block makes component ownership obvious and
prevents Storybook fixtures from becoming a second, easily missed source module.
Move reusable fixture data to a neighboring TypeScript module when it should not
live in the component's only script block.

```jsonc
{
  "scripts": {
    "lint:svelte": "phoenix-assets-lint-svelte"
  }
}
```

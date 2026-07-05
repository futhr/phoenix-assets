# @phoenix-assets/lint

The shared frontend lint tooling for `phoenix_assets` host apps (Svelte 5 +
Tailwind v4): a base **Biome** config + the **Tailwind v4 arbitrary-value
linter**. Biome lints/formats `.ts`/`.js`/`.svelte`; the Tailwind linter catches
arbitrary values that have a standard utility equivalent (`w-[180px]` → `w-45`),
which Biome can't.

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
and exits non-zero on findings. It uses Tailwind's `__unstable__loadDesignSystem`
API, so keep it aligned with your `tailwindcss` version.

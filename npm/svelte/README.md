# @phoenix-assets/svelte

The Svelte 5 runtime for [`phoenix_assets`](https://github.com/futhr/phoenix_assets).
The contracts Elixir generates are types and route strings; this package is the
small amount of runtime they call into — the shape client, the command client,
locale resolution, event modifiers, and the portable-report renderer.

## Install

```bash
pnpm add -D @phoenix-assets/svelte
```

Peers: `svelte` (`^5.7.0`) and `@electric-sql/client`. The `@tanstack/*` pair is
optional and only needed for the `/collection` subpath.

## Exports

### `@phoenix-assets/svelte`

```ts
import { createShapeStore, runCommand, resolveLocale } from "@phoenix-assets/svelte"
```

- `createShapeStore` — a reactive store over an Electric shape stream.
- `configureShapeAuth` / `authHeaders` / `createShapeUrl` — point the shape
  clients at your app's token key. The generated `$phoenix/electric` client uses
  these, so configuring auth once covers every shape.
- `runCommand` — what the generated `$phoenix/commands` client calls. Resolves to
  `{ ok: true, data }` or `{ ok: false, error, status }`; it never rejects and
  never throws, so a call site cannot read the payload without handling failure.
  Both a network failure and an error code this build does not know degrade to
  `UNKNOWN_COMMAND_ERROR`.
- `matchEvent` — exhaustive matching over a generated PubSub event union.
- `resolveLocale` — picks a locale from the generated list.
- Event modifiers — `debounce`, `throttle`, `once`, `stopPropagation`,
  `preventDefault`, `self`. Svelte 5 dropped `on:click|preventDefault`; these are
  the composable replacement.

### `@phoenix-assets/svelte/collection`

`createShapeCollection` — a TanStack DB collection backed by an Electric shape.
Kept out of the main barrel so the optional `@tanstack/*` peers stay optional.

### `@phoenix-assets/svelte/reporting`

`decodeReportEnvelope` and `PortableReport` for the renderer-neutral
portable-report contract, plus `DataTable` and the accessible table twins every
visualization renders alongside its chart.

```svelte
<script lang="ts">
  import { decodeReportEnvelope, PortableReport } from "@phoenix-assets/svelte/reporting"

  let { payload } = $props()
  const envelope = decodeReportEnvelope(payload)
</script>

<PortableReport {envelope} />
```

The decoder is deliberately strict: it rejects unknown and renderer-specific
configuration, validates every field reference, and holds string and object
callers to the same JSON-only byte and nesting limits. `layerchart` is an
internal exact dependency of this subpath — pass the contract, not renderer
options, and supply your own semantic CSS tokens and domain chrome around the
shared components.

**Two entrypoints, two strictness levels.** Know which one you are using:

| | |
|---|---|
| `decodeReportEnvelope` / `safeDecodeReportEnvelope` | the **wire boundary**. Untrusted input, every field validated, unknown keys rejected. Anything arriving from a server goes through it. |
| `PortablePanel` | takes a `PanelDefinition` **value** and renders it, with no runtime validation — by then it is your own data. |

`safeDecodeReportEnvelope` returns `{ state: "ready", envelope }` or
`{ state: "invalid", code, path }` instead of throwing, which is what you want
behind an error card. A non-contract failure still throws.

For a chart the client composes locally — no wire form, no `query_ref`, because
you already have the frame — use `composePanel`. It fills the governed defaults,
including an accessible table twin derived from the encodings. Its output is
deliberately not wire-valid; if a panel needs to travel, the owning domain issues
it.

Overriding `messages` is a `Partial`, so a key added in a later release falls
back to English rather than breaking your build. Assert against
`REPORTING_MESSAGE_KEYS` in your own test if you would rather find out at build
time.

# @phoenix-assets/doc-shell

Svelte documentation UI for the renderer-neutral `doc-shell/v1` artifact
contract. The producer can be the `doc_shell` Hex package, a host projector, or
a build step that writes JSON. Each produces the same `DocShellPresentation`.

```svelte
<script lang="ts">
  import { DocShell, type DocShellPresentation } from "@phoenix-assets/doc-shell"
  import "@phoenix-assets/doc-shell/theme.css"

  let { presentation }: { presentation: DocShellPresentation } = $props()
</script>

<DocShell {presentation} currentId="intro" currentPath="/docs/intro" />
```

The package contains no app aliases. Customize its neutral defaults using the
`DocShellTheme` prop or the documented `--doc-*` CSS custom properties. Search
uses Fuse.js by default and accepts a replacement callback for graph/vector
search. Navigation is similarly host-controlled through a `navigate` callback.

The recursive AST renderer handles all fourteen directives plus Shiki and
Mermaid code fences. `ApiReference` renders tag-grouped OpenAPI operations,
recursive schemas and examples, and a collapsible try-it panel with a lazy JSON
viewer. Dynamic links reject executable and unknown URL schemes. Try-it paths
cannot replace the configured API origin; a cross-origin `baseUrl` also needs an
exact `allowedOrigins` entry and an on-screen confirmation before sending.
Browser cookies remain same-origin-only. All assets are bundled; `pnpm
check:offline` rejects CDN references.

Shiki grammars are loaded explicitly rather than through its full bundle. See
`supportedLanguages` for the set, which covers a Phoenix + SvelteKit codebase and
the formats its docs quote. Anything else renders as plain text. Highlighting
emits both themes as `--shiki-light` / `--shiki-dark` custom properties, so the
page's `color-scheme` picks a side and a dark host needs no extra class.

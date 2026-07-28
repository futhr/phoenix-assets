# @phoenix-assets/doc-shell

Renderer-neutral Svelte documentation UI for the versioned `doc-shell/v1`
artifact contract. It renders whatever produced the artifact and knows nothing
about the producer — the `doc_shell` Hex package, a host's own projector, or a
build step that writes the JSON by hand all yield the same
`DocShellPresentation`.

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

The recursive AST renderer dispatches all fourteen directives plus Shiki and
Mermaid code fences. `ApiReference` renders tag-grouped OpenAPI operations,
recursive schemas and examples, and a collapsible try-it panel with a lazy JSON
viewer. All assets are bundled; `pnpm check:offline` rejects CDN references.

Shiki grammars are loaded explicitly rather than through its full bundle — see
`supportedLanguages` for the set, which covers a Phoenix + SvelteKit codebase and
the formats its docs quote. Anything else renders as plain text. Highlighting
emits both themes as `--shiki-light` / `--shiki-dark` custom properties, so the
page's `color-scheme` picks a side and a dark host needs no extra class.

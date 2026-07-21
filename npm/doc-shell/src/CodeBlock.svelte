<script lang="ts">
import { codeToHtml } from "shiki"

interface Props {
  code: string
  language?: string
}
const { code, language = "text" }: Props = $props()
let html = $state("")
$effect(() => {
  void codeToHtml(code, { lang: language, theme: "github-dark" })
    .then((value) => {
      html = value
    })
    .catch(() => {
      html = ""
    })
})
</script>

<div class="code-block" data-language={language}>
  <button type="button" onclick={() => navigator.clipboard?.writeText(code)}>Copy</button>
  {#if html}<div class="highlighted">{@html html}</div>{:else}<pre><code>{code}</code></pre>{/if}
</div>

<style>
  .code-block { position: relative; margin: 1rem 0; overflow: auto; border-radius: var(--doc-radius); background: #0d1117; color: #f0f6fc; }
  button { position: absolute; z-index: 1; top: .5rem; right: .5rem; border: 1px solid #48515c; border-radius: .25rem; background: #21262d; color: inherit; cursor: pointer; }
  pre, :global(.shiki) { margin: 0; padding: 1rem; overflow: auto; }
</style>

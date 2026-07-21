<script lang="ts">import type { Backlink } from "./types.js"

interface Props {
  items: Backlink[]
}
const { items }: Props = $props()
</script>
{#if items.length}<section><h2>Referenced by</h2><ul>{#each items as item (item.id)}<li><a href={item.path}>{item.title}</a></li>{/each}</ul></section>{/if}
<style>section { margin-top: 2rem; border-top: 1px solid var(--doc-border); } h2 { font-size: 1rem; } a { color: var(--doc-accent); }</style>

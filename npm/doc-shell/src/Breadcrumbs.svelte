<script lang="ts">import type { NavigationItem } from "./types.js"

interface Props {
  items: NavigationItem[]
}
const { items }: Props = $props()
</script>
<nav aria-label="Breadcrumb"><ol>{#each items as item, index (item.id)}<li><a href={item.path}>{item.title}</a>{#if index < items.length - 1}<span aria-hidden="true">/</span>{/if}</li>{/each}</ol></nav>
<style>ol { display: flex; gap: .5rem; list-style: none; padding: 0; color: var(--doc-muted); font-size: .875rem; } li { display: flex; gap: .5rem; } a { color: inherit; }</style>

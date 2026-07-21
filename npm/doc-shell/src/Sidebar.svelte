<script lang="ts">
import Sidebar from "./Sidebar.svelte"
import type { NavigationItem } from "./types.js"

interface Props {
  items: NavigationItem[]
  currentPath?: string
  navigate?: (path: string) => void
}
const { items, currentPath = "", navigate }: Props = $props()
</script>
<nav aria-label="Documentation"><ul>{#each items as item (item.id)}<li><a href={item.path} aria-current={item.path === currentPath ? "page" : undefined} onclick={(event) => { if (navigate) { event.preventDefault(); navigate(item.path) } }}>{item.title}</a>{#if item.children?.length}<Sidebar items={item.children} {currentPath} {navigate} />{/if}</li>{/each}</ul></nav>
<style>ul { list-style: none; margin: 0; padding: 0; } li :global(nav) { padding-left: .75rem; } a { display: block; padding: .35rem .5rem; border-radius: var(--doc-radius); color: inherit; text-decoration: none; } a:hover, a[aria-current="page"] { background: var(--doc-surface); color: var(--doc-accent); }</style>

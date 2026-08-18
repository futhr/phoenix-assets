<script lang="ts">
import Fuse from "fuse.js"
import type { SearchEntry } from "./types.js"
import { safeLinkTarget } from "./url.js"

interface Props {
  entries: SearchEntry[]
  navigate?: (path: string) => void
  search?: (query: string, entries: SearchEntry[]) => SearchEntry[] | Promise<SearchEntry[]>
}
const { entries, navigate, search }: Props = $props()
let open = $state(false)
let query = $state("")
let external = $state<SearchEntry[]>([])
const fuse = $derived(
  new Fuse(entries, { keys: [{ name: "title", weight: 2 }, "content"], threshold: 0.3 }),
)
const results = $derived(
  search
    ? external
    : query.length >= 2
      ? fuse.search(query, { limit: 10 }).map(({ item }) => item)
      : [],
)
$effect(() => {
  if (search && query.length >= 2)
    void Promise.resolve(search(query, entries)).then((value) => {
      external = value
    })
})
const onKey = (event: KeyboardEvent) => {
  if ((event.metaKey || event.ctrlKey) && event.key === "k") {
    event.preventDefault()
    open = true
  }
}
</script>
<svelte:window onkeydown={onKey} />
<button type="button" onclick={() => (open = true)}>Search documentation <kbd>⌘K</kbd></button>
{#if open}<div class="overlay" role="presentation" onclick={(event) => { if (event.target === event.currentTarget) open = false }}><dialog open aria-label="Search documentation"><input bind:value={query} placeholder="Search documentation…" autofocus /><ul>{#each results as item (item.id)}{const link = $derived(safeLinkTarget(item.path))}<li>{#if link}<a href={link.href} target={link.external ? "_blank" : undefined} rel={link.external ? "noopener noreferrer" : undefined} onclick={(event) => { if (navigate && link.navigable) { event.preventDefault(); navigate(item.path) } open = false }}>{item.title}</a>{:else}<span data-unsafe-link>{item.title}</span>{/if}</li>{/each}</ul><button type="button" onclick={() => (open = false)}>Close</button></dialog></div>{/if}
<style>button, input { border: 1px solid var(--doc-border); border-radius: var(--doc-radius); padding: .55rem .75rem; background: var(--doc-background); color: inherit; } kbd { color: var(--doc-muted); } .overlay { position: fixed; inset: 0; z-index: 10; display: grid; place-items: start center; padding-top: 12vh; background: rgb(0 0 0 / .35); } dialog { position: static; width: min(36rem, 90vw); margin: 0; border: 1px solid var(--doc-border); border-radius: var(--doc-radius); background: var(--doc-background); color: inherit; } input { width: 100%; } ul { list-style: none; padding: 0; } a { display: block; padding: .5rem; color: inherit; }</style>

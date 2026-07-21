<script lang="ts">
import OperationCard from "./OperationCard.svelte"
import { flattenOperations, groupOperations } from "./openapi.js"
import TryIt from "./TryIt.svelte"
import type { OpenApiDocument, OperationEntry } from "./types.js"

interface Props {
  spec: OpenApiDocument
  baseUrl?: string
}
const { spec, baseUrl = "" }: Props = $props()
const operations = $derived(flattenOperations(spec))
const groups = $derived(groupOperations(operations))
let selected = $state<OperationEntry>()
$effect(() => {
  selected ??= operations[0]
})
</script>
<div class="api-reference"><nav>{#if spec.info}<h2>{spec.info.title}</h2><small>v{spec.info.version}</small>{/if}{#each Object.entries(groups) as [tag, entries] (tag)}<h3>{tag}</h3>{#each entries ?? [] as entry (entry.id)}<button type="button" onclick={() => (selected = entry)}><strong>{entry.method}</strong> {entry.path}</button>{/each}{/each}</nav><main>{#if selected}<OperationCard entry={selected} /><TryIt entry={selected} {baseUrl} />{/if}</main></div>
<style>.api-reference { display: grid; grid-template-columns: minmax(12rem, 16rem) 1fr; gap: 1.5rem; } nav button { display: block; width: 100%; border: 0; padding: .4rem; background: none; color: inherit; text-align: left; cursor: pointer; } nav button:hover { background: var(--doc-surface); } @media (max-width: 50rem) { .api-reference { grid-template-columns: 1fr; } }</style>

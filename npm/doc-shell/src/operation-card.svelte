<script lang="ts">
import { schemaFrom } from "./openapi.js"
import SchemaTable from "./schema-table.svelte"
import type { OperationEntry } from "./types.js"

interface Props {
  entry: OperationEntry
}
const { entry }: Props = $props()
const responses = $derived(Object.entries(entry.operation.responses ?? {}))
const request = $derived(schemaFrom(entry.operation.requestBody?.content))
</script>
<article><header><strong>{entry.method}</strong> <code>{entry.path}</code></header>{#if entry.operation.summary}<p>{entry.operation.summary}</p>{/if}{#if entry.operation.parameters?.length}<h3>Parameters</h3><ul>{#each entry.operation.parameters as parameter (parameter.name + parameter.in)}<li><code>{parameter.name}</code> — {parameter.in}{parameter.required ? " (required)" : ""} {parameter.description ?? ""}</li>{/each}</ul>{/if}{#if request}<h3>Request body</h3><SchemaTable schema={request} />{/if}{#if responses.length}<h3>Responses</h3>{#each responses as [status, response] (status)}{const schema = $derived(schemaFrom(response.content))}<section><strong>{status}</strong> {response.description ?? ""}{#if schema}<SchemaTable {schema} />{/if}</section>{/each}{/if}</article>
<style>article { border: 1px solid var(--doc-border); border-radius: var(--doc-radius); padding: 1rem; } header { display: flex; gap: .5rem; } header strong { color: var(--doc-accent); }</style>

<script lang="ts">
import type { ResultFrame } from "./contract.js"
import { formatCell } from "./format.js"

let {
  frame,
  columns,
  caption,
  locale,
}: {
  frame: ResultFrame
  columns?: string[]
  caption: string
  locale?: string
} = $props()

const fieldIndexes = $derived(
  (columns?.length ? columns : frame.fields.map((field) => field.name))
    .map((name) => ({
      field: frame.fields.find((field) => field.name === name),
      index: frame.fields.findIndex((field) => field.name === name),
    }))
    .filter(
      (entry): entry is { field: ResultFrame["fields"][number]; index: number } =>
        entry.field !== undefined && entry.index >= 0,
    ),
)
</script>

<!-- svelte-ignore a11y_no_noninteractive_tabindex (keyboard scrolling for an overflow region) -->
<div class="pa-report-table-wrap" role="region" aria-label={`${caption} data table`} tabindex="0">
  <table class="pa-report-table">
    <caption>{caption}</caption>
    <thead>
      <tr>
        {#each fieldIndexes as { field }}
          <th scope="col">{field.label}{field.unit && field.unit !== "count" ? ` (${field.unit})` : ""}</th>
        {/each}
      </tr>
    </thead>
    <tbody>
      {#each frame.rows as row}
        <tr>
          {#each fieldIndexes as { field, index }}
            <td>{formatCell(row[index], field, locale)}</td>
          {/each}
        </tr>
      {:else}
        <tr><td colspan={fieldIndexes.length || 1}>No rows</td></tr>
      {/each}
    </tbody>
  </table>
</div>

<style>
  .pa-report-table-wrap { max-width: 100%; overflow: auto; }
  .pa-report-table { width: 100%; border-collapse: collapse; color: var(--pa-report-foreground, currentColor); font: inherit; }
  caption { padding: 0.5rem; text-align: start; font-weight: 600; }
  th, td { padding: 0.5rem 0.75rem; border-block-end: 1px solid var(--pa-report-border, color-mix(in srgb, currentColor 20%, transparent)); text-align: start; white-space: nowrap; }
  th { font-weight: 600; }
  .pa-report-table-wrap:focus-visible { outline: 2px solid var(--pa-report-focus, currentColor); outline-offset: 2px; }
</style>

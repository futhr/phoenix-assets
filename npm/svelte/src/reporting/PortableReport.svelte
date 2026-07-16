<script lang="ts">
import type { ReportEnvelope } from "./contract.js"
import PortablePanel from "./PortablePanel.svelte"

let { envelope, locale }: { envelope: ReportEnvelope; locale?: string } = $props()
</script>

<article class="pa-report" aria-labelledby="pa-report-title">
  <header>
    <h1 id="pa-report-title">{envelope.definition.title}</h1>
    <p>{envelope.definition.description}</p>
  </header>
  {#if envelope.capability_warnings.length > 0}
    <p class="pa-report-warning" role="status">Some panels use an accessible fallback on this device.</p>
  {/if}
  <div class="pa-report-grid">
    {#each envelope.definition.panels as panel (panel.id)}
      <PortablePanel {panel} result={envelope.results[panel.id]!} {locale} />
    {/each}
  </div>
</article>

<style>
  .pa-report { display: grid; gap: 1.5rem; min-width: 0; color: var(--pa-report-foreground, currentColor); }
  header h1, header p { margin: 0; } header p { margin-block-start: 0.375rem; color: var(--pa-report-muted, color-mix(in srgb, currentColor 70%, transparent)); }
  .pa-report-grid { display: grid; grid-template-columns: repeat(12, minmax(0, 1fr)); gap: var(--pa-report-grid-gap, 1rem); }
  .pa-report-grid > :global(*) { grid-column: span 6; }
  .pa-report-warning { padding: 0.75rem; border-inline-start: 0.25rem solid var(--pa-report-warning, #d97706); background: var(--pa-report-state-surface, color-mix(in srgb, currentColor 8%, transparent)); }
  @media (max-width: 48rem) { .pa-report-grid > :global(*) { grid-column: 1 / -1; } }
</style>

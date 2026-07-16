<script lang="ts">
import { AreaChart, BarChart, LineChart, ScatterChart } from "layerchart"
import { type ChartDatum, compilePanel } from "./compile.js"
import type { PanelDefinition, PanelResult } from "./contract.js"
import DataTable from "./DataTable.svelte"
import { formatCell } from "./format.js"
import HeatmapChart from "./HeatmapChart.svelte"

let { panel, result, locale }: { panel: PanelDefinition; result: PanelResult; locale?: string } =
  $props()
let tableVisible = $state(false)
const frame = $derived(
  result.state === "ok" || result.state === "partial" ? result.frame : undefined,
)
const compiled = $derived(frame ? compilePanel(panel, frame) : undefined)
const summaryId = $derived(`pa-report-summary-${panel.id}`)
const tableId = $derived(`pa-report-table-${panel.id}`)
const palette = [
  "var(--pa-report-series-1, #2563eb)",
  "var(--pa-report-series-2, #dc2626)",
  "var(--pa-report-series-3, #059669)",
  "var(--pa-report-series-4, #7c3aed)",
  "var(--pa-report-series-5, #d97706)",
  "var(--pa-report-series-6, #0891b2)",
]
const series = $derived.by(() => {
  const seriesField = compiled?.series
  const valueField = compiled?.y
  if (!seriesField || !valueField) return undefined
  return compiled.seriesValues.map((key, index) => ({
    key,
    label: key,
    color: palette[index % palette.length],
    value: (datum: ChartDatum) => (datum[seriesField] === key ? datum[valueField] : null),
  }))
})
const scalarField = $derived(compiled?.value ? compiled.fields.get(compiled.value) : undefined)
const scalarValue = $derived(compiled?.value ? compiled.data.at(-1)?.[compiled.value] : undefined)
</script>

<section class="pa-report-panel" aria-labelledby={`${panel.id}-title`} aria-describedby={summaryId}>
  <header>
    <div>
      <h2 id={`${panel.id}-title`}>{panel.title}</h2>
      <p id={summaryId}>{panel.description}</p>
    </div>
    {#if result.state === "ok" || result.state === "partial"}
      <button type="button" aria-controls={tableId} aria-expanded={tableVisible} onclick={() => tableVisible = !tableVisible}>
        {tableVisible ? "Hide table" : "View as table"}
      </button>
    {/if}
  </header>

  {#if result.state === "empty"}
    <p class="pa-report-state" role="status">{panel.empty_message}</p>
  {:else if result.state === "error"}
    <p class="pa-report-state pa-report-error" role="alert">This panel is unavailable.</p>
  {:else if compiled && frame}
    {#if result.state === "partial"}
      <p class="pa-report-state pa-report-warning" role="status">This result is partial. Review its evidence before use.</p>
    {/if}

    {#if compiled.kind === "number" && scalarField && scalarValue !== undefined}
      <p class="pa-report-number">{formatCell(scalarValue, scalarField, locale)}</p>
    {:else if compiled.kind === "gauge" && scalarField && typeof scalarValue === "number"}
      <div class="pa-report-gauge">
        <span>{formatCell(scalarValue, scalarField, locale)}</span>
        <progress value={Math.max(0, Math.min(100, scalarValue))} max="100">{scalarValue}%</progress>
      </div>
    {:else if compiled.chartable && compiled.x && compiled.y && (compiled.kind === "line" || compiled.kind === "sparkline")}
      <div class:pa-report-sparkline={compiled.kind === "sparkline"} class="pa-report-chart" aria-hidden="true">
        <LineChart data={compiled.data} x={compiled.x} y={compiled.y} {series} motion="none" />
      </div>
    {:else if compiled.chartable && compiled.x && compiled.y && compiled.kind === "area"}
      <div class="pa-report-chart" aria-hidden="true"><AreaChart data={compiled.data} x={compiled.x} y={compiled.y} {series} motion="none" /></div>
    {:else if compiled.chartable && compiled.x && compiled.y && compiled.kind === "bar"}
      <div class="pa-report-chart" aria-hidden="true"><BarChart data={compiled.data} x={compiled.x} y={compiled.y} {series} seriesLayout={panel.visualization.stack === "normalized" ? "stackExpand" : panel.visualization.stack === "normal" ? "stack" : compiled.series ? "group" : "overlap"} motion="none" /></div>
    {:else if compiled.chartable && compiled.x && compiled.y && compiled.kind === "scatter"}
      <div class="pa-report-chart" aria-hidden="true"><ScatterChart data={compiled.data} x={compiled.x} y={compiled.y} {series} motion="none" /></div>
    {:else if compiled.chartable && compiled.x && compiled.y && compiled.value && compiled.kind === "heatmap"}
      <div class="pa-report-chart" aria-hidden="true"><HeatmapChart {compiled} /></div>
    {:else}
      <p class="pa-report-state" role="status">A safe chart is unavailable; the complete table is shown.</p>
      <div id={tableId}><DataTable {frame} columns={panel.table_columns} caption={panel.title} {locale} /></div>
    {/if}

    {#if tableVisible && compiled.kind !== "table"}
      <div id={tableId}><DataTable {frame} columns={panel.table_columns} caption={panel.title} {locale} /></div>
    {:else if compiled.kind === "table"}
      <div id={tableId}><DataTable {frame} columns={panel.table_columns} caption={panel.title} {locale} /></div>
    {/if}

    <footer>
      <span>State: {result.state}</span>
      {#if typeof frame.freshness.watermark === "string"}<span>Watermark: {frame.freshness.watermark}</span>{/if}
      {#if frame.page.truncated === true}<strong>Truncated</strong>{/if}
    </footer>
  {/if}
</section>

<style>
  .pa-report-panel { display: grid; gap: 1rem; min-width: 0; padding: var(--pa-report-panel-padding, 1rem); border: 1px solid var(--pa-report-border, color-mix(in srgb, currentColor 20%, transparent)); border-radius: var(--pa-report-radius, 0.75rem); background: var(--pa-report-surface, transparent); color: var(--pa-report-foreground, currentColor); }
  header { display: flex; align-items: start; justify-content: space-between; gap: 1rem; }
  h2, p { margin: 0; } h2 { font-size: 1rem; } header p { margin-block-start: 0.25rem; color: var(--pa-report-muted, color-mix(in srgb, currentColor 70%, transparent)); }
  button { min-height: 2.75rem; padding: 0.5rem 0.75rem; border: 1px solid var(--pa-report-border, currentColor); border-radius: 0.5rem; background: var(--pa-report-control, transparent); color: inherit; font: inherit; }
  button:focus-visible { outline: 2px solid var(--pa-report-focus, currentColor); outline-offset: 2px; }
  .pa-report-chart { min-height: 18rem; } .pa-report-sparkline { min-height: 5rem; }
  .pa-report-number { font-size: clamp(2rem, 8vw, 4rem); font-variant-numeric: tabular-nums; }
  .pa-report-gauge { display: grid; gap: 0.5rem; font-size: 1.5rem; font-variant-numeric: tabular-nums; } progress { width: 100%; accent-color: var(--pa-report-series-1, #2563eb); }
  .pa-report-state { padding: 0.75rem; background: var(--pa-report-state-surface, color-mix(in srgb, currentColor 8%, transparent)); border-radius: 0.5rem; }
  .pa-report-warning { border-inline-start: 0.25rem solid var(--pa-report-warning, #d97706); } .pa-report-error { border-inline-start: 0.25rem solid var(--pa-report-error, #dc2626); }
  footer { display: flex; flex-wrap: wrap; gap: 0.5rem 1rem; font-size: 0.875rem; color: var(--pa-report-muted, color-mix(in srgb, currentColor 70%, transparent)); }
  @media (max-width: 30rem) { header { display: grid; } .pa-report-chart { min-height: 14rem; } }
  @media (prefers-reduced-motion: reduce) { *, *::before, *::after { scroll-behavior: auto !important; transition-duration: 0.01ms !important; } }
</style>

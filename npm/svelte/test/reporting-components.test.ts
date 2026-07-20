import { mount, tick, unmount } from "svelte"
import { describe, expect, it } from "vitest"
import type { PanelDefinition, ResultFrame } from "../src/reporting/contract"
import DataTable from "../src/reporting/DataTable.svelte"
import PortablePanel from "../src/reporting/PortablePanel.svelte"
import PortableReport from "../src/reporting/PortableReport.svelte"

describe("portable report components", () => {
  it("renders exact values in a semantic table", () => {
    const target = document.createElement("div")
    const component = mount(DataTable, {
      target,
      props: { frame: frameFixture(), columns: ["amount"], caption: "Revenue", locale: "sv-SE" },
    })

    expect(target.innerHTML).toContain("<table")
    expect(target.querySelector("caption")?.textContent).toBe("Revenue")
    expect(target.textContent).toContain("12.50 SEK")
    expect(target.textContent).not.toContain("evaluated_at")
    unmount(component)
  })

  it("renders explicit empty and error states without creating a chart", () => {
    const target = document.createElement("div")
    const empty = mount(PortablePanel, {
      target,
      props: { panel: panelFixture(), result: { state: "empty" } },
    })
    expect(target.textContent).toContain("No settled revenue exists")
    unmount(empty)

    const failed = mount(PortablePanel, {
      target,
      props: { panel: panelFixture(), result: { state: "error" } },
    })
    expect(target.textContent).toContain("This panel is unavailable")
    unmount(failed)
  })

  it("mounts the canonical LayerChart renderer for a valid line panel", () => {
    const target = document.createElement("div")
    const component = mount(PortablePanel, {
      target,
      props: { panel: panelFixture(), result: { state: "ok", frame: frameFixture() } },
    })

    expect(target.querySelector(".pa-report-chart")).not.toBeNull()
    expect(target.textContent).not.toContain("A safe chart is unavailable")
    unmount(component)
  })

  it("mounts the shared LayerChart heatmap primitive", () => {
    const target = document.createElement("div")
    const panel = panelFixture()
    panel.visualization.kind = "heatmap"
    panel.visualization.encodings = { x: "region", y: "period", value: "amount" }
    panel.table_columns = ["region", "period", "amount"]
    const component = mount(PortablePanel, {
      target,
      props: { panel, result: { state: "ok", frame: heatmapFrameFixture() } },
    })

    expect(target.querySelector('[data-report-chart="heatmap"]')).not.toBeNull()
    const fills = [...target.querySelectorAll(".lc-rect")].map((cell) => cell.getAttribute("fill"))
    expect(fills).toHaveLength(2)
    expect(new Set(fills).size).toBe(2)
    expect(fills.every((fill) => fill?.startsWith("color-mix("))).toBe(true)
    expect(target.textContent).not.toContain("A safe chart is unavailable")
    unmount(component)
  })

  it("keeps labelled relationships unique across multiple report instances", () => {
    const target = document.createElement("div")
    const first = mount(PortableReport, { target, props: { envelope: envelopeFixture() } })
    const second = mount(PortableReport, { target, props: { envelope: envelopeFixture() } })

    const ids = [...target.querySelectorAll<HTMLElement>("[id]")].map((element) => element.id)
    expect(new Set(ids).size).toBe(ids.length)

    for (const element of target.querySelectorAll<HTMLElement>("[aria-labelledby]")) {
      const reference = element.getAttribute("aria-labelledby")
      expect(reference).not.toBeNull()
      expect(target.querySelectorAll(`#${reference}`).length).toBe(1)
    }

    for (const element of target.querySelectorAll<HTMLElement>("[aria-describedby]")) {
      const reference = element.getAttribute("aria-describedby")
      expect(reference).not.toBeNull()
      expect(target.querySelectorAll(`#${reference}`).length).toBe(1)
    }

    unmount(first)
    unmount(second)
  })

  it("honors portable panel order, columns, spans, and localized renderer messages", () => {
    const target = document.createElement("div")
    const envelope = envelopeFixture()
    const secondPanel = { ...panelFixture(), id: "summary", title: "Summary" }
    envelope.definition.panels.push(secondPanel)
    envelope.results.summary = { state: "error" }
    envelope.capability_warnings.push({ code: "narrow_layout" })
    envelope.definition.layout = {
      columns: 8,
      order: ["summary", "trend"],
      spans: { summary: 8, trend: 4 },
    }
    const component = mount(PortableReport, {
      target,
      props: {
        envelope,
        messages: {
          accessibleFallback: "Anpassad tabellvy används.",
          panelUnavailable: "Panelen är inte tillgänglig.",
        },
      },
    })

    const grid = target.querySelector<HTMLElement>(".pa-report-grid")
    const wrappers = [...target.querySelectorAll<HTMLElement>(".pa-report-grid-panel")]
    expect(grid?.style.getPropertyValue("--pa-report-columns")).toBe("8")
    expect(wrappers.map((wrapper) => wrapper.querySelector("h2")?.textContent)).toEqual([
      "Summary",
      "Revenue",
    ])
    expect(
      wrappers.map((wrapper) => wrapper.style.getPropertyValue("--pa-report-panel-span")),
    ).toEqual(["8", "4"])
    expect(target.textContent).toContain("Anpassad tabellvy används.")
    expect(target.textContent).toContain("Panelen är inte tillgänglig.")
    unmount(component)
  })

  it("exposes a keyboard-focusable table alternative with synchronized state", async () => {
    const target = document.createElement("div")
    const component = mount(PortablePanel, {
      target,
      props: { panel: panelFixture(), result: { state: "ok", frame: frameFixture() } },
    })
    const button = target.querySelector("button")

    expect(button?.tabIndex).toBe(0)
    expect(button?.getAttribute("aria-expanded")).toBe("false")
    expect(target.querySelector("table")).toBeNull()

    button?.click()
    await tick()

    expect(button?.getAttribute("aria-expanded")).toBe("true")
    const controlledId = button?.getAttribute("aria-controls")
    expect(controlledId).not.toBeNull()
    expect(target.querySelector(`#${controlledId} table caption`)?.textContent).toBe("Revenue")
    expect(target.textContent).toContain("12.50 SEK")
    unmount(component)
  })
})

function envelopeFixture() {
  return {
    definition: {
      schema_version: "1.0",
      id: "report-1",
      title: "Revenue report",
      description: "Authorized settled revenue.",
      panels: [panelFixture()],
      layout: {},
      parameters: [],
      provenance: {},
    },
    results: { trend: { state: "ok" as const, frame: frameFixture() } },
    capability_warnings: [],
    generated_at: "2026-07-17T12:00:00Z",
  }
}

function panelFixture(): PanelDefinition {
  return {
    id: "trend",
    title: "Revenue",
    description: "Settled revenue by evaluation time.",
    query_ref: "metric:settled-revenue:v1",
    visualization: {
      kind: "line",
      encodings: { x: "evaluated_at", y: "amount" },
      formats: {},
      sort: [],
      stack: "none",
      annotations: [],
      interaction: {},
      summary_template: "Settled revenue trend.",
    },
    table_columns: ["evaluated_at", "amount"],
    empty_message: "No settled revenue exists for the effective scope.",
  }
}

function frameFixture(): ResultFrame {
  return {
    fields: [
      {
        name: "evaluated_at",
        label: "Evaluated at",
        type: "datetime",
        role: "time",
        unit: null,
        nullable: false,
        classification: "internal",
      },
      {
        name: "amount",
        label: "Amount",
        type: "decimal",
        role: "measure",
        unit: "SEK",
        nullable: false,
        classification: "internal",
      },
    ],
    rows: [["2026-07-16T10:00:00Z", "12.50"]],
    provenance: {},
    freshness: {},
    classification: {},
    page: { truncated: false },
  }
}

function heatmapFrameFixture(): ResultFrame {
  return {
    fields: [
      {
        name: "region",
        label: "Region",
        type: "string",
        role: "dimension",
        unit: null,
        nullable: false,
        classification: "internal",
      },
      {
        name: "period",
        label: "Period",
        type: "string",
        role: "dimension",
        unit: null,
        nullable: false,
        classification: "internal",
      },
      {
        name: "amount",
        label: "Amount",
        type: "float",
        role: "measure",
        unit: "SEK",
        nullable: false,
        classification: "internal",
      },
    ],
    rows: [
      ["North", "Q1", 12.5],
      ["South", "Q1", 9.25],
    ],
    provenance: {},
    freshness: {},
    classification: {},
    page: { truncated: false },
  }
}

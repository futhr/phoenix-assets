import { mount, unmount } from "svelte"
import { describe, expect, it } from "vitest"
import type { PanelDefinition, ResultFrame } from "../src/reporting/contract"
import DataTable from "../src/reporting/DataTable.svelte"
import PortablePanel from "../src/reporting/PortablePanel.svelte"

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
})

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

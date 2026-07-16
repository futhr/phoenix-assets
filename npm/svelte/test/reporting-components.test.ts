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

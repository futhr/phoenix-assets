import { describe, expect, it } from "vitest"
import {
  composePanel,
  DEFAULT_REPORTING_MESSAGES,
  decodeReportEnvelope,
  REPORTING_MESSAGE_KEYS,
  safeDecodeReportEnvelope,
} from "../src/reporting/index.js"

describe("REPORTING_MESSAGE_KEYS", () => {
  it("lists every key a host can override", () => {
    expect([...REPORTING_MESSAGE_KEYS].sort()).toEqual(
      Object.keys(DEFAULT_REPORTING_MESSAGES).sort(),
    )
  })
})

describe("safeDecodeReportEnvelope", () => {
  it("returns the envelope when the input is contract-valid", () => {
    const envelope = {
      definition: {
        schema_version: "1.0",
        id: null,
        title: "Revenue",
        description: "Monthly revenue",
        panels: [],
        layout: {},
        parameters: [],
        provenance: {},
      },
      results: {},
      capability_warnings: [],
      generated_at: "2026-07-28T00:00:00Z",
    }

    const decoded = safeDecodeReportEnvelope(envelope)

    expect(decoded.state).toBe("ready")
    expect(decoded).toMatchObject({ envelope: { definition: { title: "Revenue" } } })
  })

  it("returns the contract error as a value, with its code and path", () => {
    const decoded = safeDecodeReportEnvelope({ definition: {} })

    expect(decoded.state).toBe("invalid")
    expect(decoded).toMatchObject({ code: expect.any(String), path: expect.any(Array) })
  })

  it("agrees with the throwing decoder on what is valid", () => {
    expect(() => decodeReportEnvelope({ definition: {} })).toThrow()
  })

  // Swallowing a non-contract failure would turn a bug in this package into a
  // shrug on the host's error card.
  it("still throws when the failure is not a contract rejection", () => {
    const exploding = {
      get definition() {
        throw new TypeError("boom")
      },
    }

    expect(() => safeDecodeReportEnvelope(exploding)).toThrow(TypeError)
  })
})

describe("composePanel", () => {
  it("fills the governed defaults a client-composed chart needs", () => {
    const panel = composePanel({
      title: "Yield by Line",
      kind: "bar",
      encodings: { x: "line", y: "yield" },
    })

    expect(panel.id).toBe("yield-by-line")
    expect(panel.visualization.summary_template).toBe("Yield by Line")
    expect(panel.visualization.stack).toBe("none")
    expect(panel.empty_message).not.toBe("")
  })

  // A chart with no table twin is unreadable to anyone not looking at it.
  it("derives the accessible table columns from the encodings", () => {
    const panel = composePanel({
      title: "Trend",
      kind: "line",
      encodings: { x: "at", y: "value", series: "at" },
    })

    expect(panel.table_columns).toEqual(["at", "value"])
  })

  it("honours explicit overrides", () => {
    const panel = composePanel({
      id: "custom",
      title: "Trend",
      kind: "line",
      encodings: { x: "at", y: "value" },
      tableColumns: ["value"],
      summary: "How value moved",
    })

    expect(panel).toMatchObject({ id: "custom", table_columns: ["value"] })
    expect(panel.visualization.summary_template).toBe("How value moved")
  })

  // The composed panel is for local rendering only; it has no wire form, and
  // the decoder rejecting it is the boundary working, not a bug.
  it("produces a panel the wire decoder rejects, by design", () => {
    const panel = composePanel({ title: "Local", kind: "number", encodings: { value: "n" } })

    expect(panel.query_ref).toBe("")

    const decoded = safeDecodeReportEnvelope({
      definition: {
        schema_version: "1.0",
        id: null,
        title: "Local",
        description: "",
        panels: [panel],
        layout: {},
        parameters: [],
        provenance: {},
      },
      results: {},
      capability_warnings: [],
      generated_at: "2026-07-28T00:00:00Z",
    })

    expect(decoded.state).toBe("invalid")
  })
})

import { describe, expect, it } from "vitest"
import { compilePanel } from "../src/reporting/compile"
import { ReportingContractError } from "../src/reporting/contract"
import { decodeReportEnvelope, decodeResultFrame } from "../src/reporting/decode"
import { formatCell } from "../src/reporting/format"

describe("portable reporting contract", () => {
  it("strictly decodes and binds a complete envelope", () => {
    const envelope = decodeReportEnvelope(envelopeFixture())

    expect(envelope.definition.panels[0]?.visualization.kind).toBe("line")
    expect(envelope.results.trend?.state).toBe("ok")
  })

  it("rejects renderer configuration and unknown field bindings", () => {
    const rendererConfig = envelopeFixture()
    const firstPanel = rendererConfig.definition.panels[0]
    if (!firstPanel) throw new Error("fixture must contain a panel")
    const visualization = firstPanel.visualization as Record<string, unknown>
    visualization.url = "https://example.test/data.json"

    expectContractError(() => decodeReportEnvelope(rendererConfig), "unknown_keys")

    const unknownField = envelopeFixture()
    const unknownFieldPanel = unknownField.definition.panels[0]
    if (!unknownFieldPanel) throw new Error("fixture must contain a panel")
    unknownFieldPanel.visualization.encodings.y = "missing"
    expectContractError(() => decodeReportEnvelope(unknownField), "unknown_field")
  })

  it("enforces row types, widths, and byte limits", () => {
    const invalidDecimal = frameFixture()
    firstRow(invalidDecimal)[1] = 12.5
    expectContractError(() => decodeResultFrame(invalidDecimal), "invalid_cell")

    const invalidWidth = frameFixture()
    invalidWidth.rows[0] = ["2026-07-16T10:00:00Z"]
    expectContractError(() => decodeResultFrame(invalidWidth), "row_width_mismatch")

    expectContractError(
      () => decodeResultFrame(JSON.stringify(frameFixture()), { maxBytes: 10 }),
      "limit_exceeded",
    )

    const invalidDate = frameFixture()
    firstRow(invalidDate)[0] = "2026-02-31T10:00:00Z"
    expectContractError(() => decodeResultFrame(invalidDate), "invalid_cell")

    const nonJson = frameFixture()
    nonJson.provenance.callback = () => undefined
    expectContractError(() => decodeResultFrame(nonJson), "invalid_json_value")
  })

  it("compiles only safe, closed chart data", () => {
    const envelope = decodeReportEnvelope(envelopeFixture())
    const panel = envelope.definition.panels[0]
    const result = envelope.results.trend
    if (!panel || !result) throw new Error("fixture must contain a panel result")
    if (result.state !== "ok") throw new Error("fixture must be ok")

    const compiled = compilePanel(panel, result.frame)
    expect(compiled.chartable).toBe(true)
    expect(compiled.data[0]).toEqual({ evaluated_at: "2026-07-16T10:00:00Z", amount: 12.5 })

    firstRow(result.frame)[1] = "900719925474099312345.50"
    const unsafe = compilePanel(panel, result.frame)
    expect(unsafe).toMatchObject({ chartable: false, fallbackReason: "unsafe_numeric_value" })
  })

  it("keeps exact decimal text in accessible formatting", () => {
    const amount = decodeResultFrame(frameFixture()).fields[1]
    if (!amount) throw new Error("fixture must contain an amount field")
    expect(formatCell("12.50", amount, "sv-SE")).toBe("12.50 SEK")
  })

  it("normalizes optional definition and visualization fields", () => {
    const fixture = envelopeFixture()
    delete (fixture.definition as { id?: string }).id
    delete (fixture.definition as { parameters?: unknown[] }).parameters
    const visualization = fixture.definition.panels[0]?.visualization
    if (!visualization) throw new Error("fixture must contain visualization")
    Object.assign(visualization, {
      formats: { amount: "currency" },
      sort: [{ field: "evaluated_at", direction: "asc" }],
      stack: "normal",
      annotations: [{ text: "Latest", field: "amount" }],
      interaction: { selection: "point", drill_action_id: "open_detail" },
    })

    const decoded = decodeReportEnvelope(fixture)
    expect(decoded.definition.id).toBeNull()
    expect(decoded.definition.parameters).toEqual([])
    expect(decoded.definition.panels[0]?.visualization).toMatchObject({ stack: "normal" })
  })

  it("requires kind channels and binds format and annotation fields", () => {
    const missingChannel = envelopeFixture()
    delete missingChannel.definition.panels[0]?.visualization.encodings.y
    expectContractError(() => decodeReportEnvelope(missingChannel), "missing_encodings")

    const unknownFormat = envelopeFixture()
    Object.assign(unknownFormat.definition.panels[0]?.visualization, {
      formats: { missing: "number" },
    })
    expectContractError(() => decodeReportEnvelope(unknownFormat), "unknown_field")

    const unknownAnnotation = envelopeFixture()
    Object.assign(unknownAnnotation.definition.panels[0]?.visualization, {
      annotations: [{ text: "Target", field: "missing" }],
    })
    expectContractError(() => decodeReportEnvelope(unknownAnnotation), "unknown_field")
  })

  it("decodes explicit empty, partial, and error states", () => {
    const empty = envelopeFixture()
    empty.results.trend = { state: "empty", detail: { code: "no_rows" } } as never
    expect(decodeReportEnvelope(empty).results.trend?.state).toBe("empty")

    const partial = envelopeFixture()
    partial.results.trend.state = "partial"
    expect(decodeReportEnvelope(partial).results.trend?.state).toBe("partial")

    const failed = envelopeFixture()
    failed.results.trend = { state: "error" } as never
    expect(decodeReportEnvelope(failed).results.trend?.state).toBe("error")
  })

  it("rejects unsafe primitive and schema variants", () => {
    expectContractError(() => decodeResultFrame(null), "expected_object")
    const invalidEnum = frameFixture()
    const firstField = invalidEnum.fields[0]
    if (!firstField) throw new Error("fixture must contain fields")
    firstField.type = "object"
    expectContractError(() => decodeResultFrame(invalidEnum), "invalid_enum")

    const duplicate = frameFixture()
    const secondField = duplicate.fields[1]
    if (!secondField) throw new Error("fixture must contain fields")
    secondField.name = "evaluated_at"
    expectContractError(() => decodeResultFrame(duplicate), "duplicate")

    const nullCell = frameFixture()
    firstRow(nullCell)[1] = null
    expectContractError(() => decodeResultFrame(nullCell), "invalid_cell")
  })

  it("formats governed scalar types without changing exact decimals", () => {
    const frame = decodeResultFrame(frameFixture())
    const amount = frame.fields[1]
    if (!amount) throw new Error("fixture must contain amount")
    expect(formatCell(null, amount)).toBe("—")
    expect(formatCell(12, { ...amount, type: "integer", unit: "count" }, "en-US")).toBe("12")
    expect(formatCell(12.5, { ...amount, type: "float", unit: "percent" }, "en-US")).toBe("13%")
    expect(formatCell(true, { ...amount, type: "boolean", unit: null })).toBe("Yes")
    expect(formatCell(50, { ...amount, type: "duration", unit: "ms" })).toBe("50 ms")
  })
})

function expectContractError(action: () => unknown, code: string): void {
  try {
    action()
    throw new Error("expected ReportingContractError")
  } catch (error) {
    expect(error).toBeInstanceOf(ReportingContractError)
    expect((error as ReportingContractError).code).toBe(code)
  }
}

function firstRow(frame: { rows: unknown[][] }): unknown[] {
  const row = frame.rows[0]
  if (!row) throw new Error("fixture must contain a row")
  return row
}

function envelopeFixture() {
  return {
    definition: {
      schema_version: "1.0",
      id: "report-1",
      title: "Revenue trend",
      description: "Authorized settled revenue over time.",
      panels: [
        {
          id: "trend",
          title: "Revenue",
          description: "Settled revenue by evaluation time.",
          query_ref: "metric:settled-revenue:v1",
          visualization: {
            kind: "line",
            encodings: { x: "evaluated_at", y: "amount" },
            summary_template: "Settled revenue trend.",
          },
          table_columns: ["evaluated_at", "amount"],
          empty_message: "No settled revenue exists for the effective scope.",
        },
      ],
      layout: { columns: 12 },
      parameters: [],
      provenance: { author_kind: "human", created_at: "2026-07-16T10:00:00Z" },
    },
    results: { trend: { state: "ok", frame: frameFixture() } },
    capability_warnings: [],
    generated_at: "2026-07-16T10:01:00Z",
  }
}

function frameFixture() {
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
    rows: [["2026-07-16T10:00:00Z", "12.50"]] as unknown[][],
    provenance: { query_ref: "metric:settled-revenue:v1", execution_id: "execution-1" },
    freshness: { watermark: "2026-07-16T09:59:00Z", stale: false },
    classification: { highest: "internal", redactions: [] },
    page: { truncated: false, cursor: null },
  }
}

import {
  CLASSIFICATIONS,
  DEFAULT_REPORTING_LIMITS,
  FIELD_ROLES,
  FIELD_TYPES,
  PANEL_STATES,
  type PanelDefinition,
  type PanelResult,
  type ReportDefinition,
  type ReportEnvelope,
  ReportingContractError,
  type ReportingLimits,
  type ResultField,
  type ResultFrame,
  VISUALIZATION_KINDS,
  type VisualizationDefinition,
} from "./contract.js"

type Path = Array<string | number>
type JsonObject = Record<string, unknown>

const encoder = new TextEncoder()
const IDENTIFIER = /^[A-Za-z_][A-Za-z0-9_.:-]{0,255}$/
const DECIMAL = /^-?(?:0|[1-9]\d*)(?:\.\d+)?$/

export function decodeReportEnvelope(
  input: string | unknown,
  overrides: Partial<ReportingLimits> = {},
): ReportEnvelope {
  const limits = { ...DEFAULT_REPORTING_LIMITS, ...overrides }
  const value = typeof input === "string" ? parseJson(input, limits) : input
  const object = expectObject(value, [])
  exactKeys(object, ["definition", "results", "capability_warnings", "generated_at"], [])

  const definition = decodeDefinition(object.definition, ["definition"], limits)
  const rawResults = expectObject(object.results, ["results"])
  const panelIds = new Set(definition.panels.map((panel) => panel.id))
  exactKeys(rawResults, [...panelIds], ["results"])

  const results: Record<string, PanelResult> = {}
  for (const panel of definition.panels) {
    const result = decodePanelResult(rawResults[panel.id], ["results", panel.id], limits)
    results[panel.id] = result
    if (result.state === "ok" || result.state === "partial") validateBindings(panel, result.frame)
  }

  const warnings = expectArray(object.capability_warnings, ["capability_warnings"]).map(
    (warning, index) => expectObject(warning, ["capability_warnings", index]),
  )

  return {
    definition,
    results,
    capability_warnings: warnings,
    generated_at: expectDateTime(object.generated_at, ["generated_at"]),
  }
}

export function decodeResultFrame(
  input: string | unknown,
  overrides: Partial<ReportingLimits> = {},
): ResultFrame {
  const limits = { ...DEFAULT_REPORTING_LIMITS, ...overrides }
  const value = typeof input === "string" ? parseJson(input, limits) : input
  return decodeFrame(value, [], limits)
}

function parseJson(input: string, limits: ReportingLimits): unknown {
  if (encoder.encode(input).byteLength > limits.maxBytes)
    fail("limit_exceeded", [], "JSON exceeds maxBytes")
  try {
    return JSON.parse(input)
  } catch {
    return fail("invalid_json", [], "Input is not valid JSON")
  }
}

function decodeDefinition(value: unknown, path: Path, limits: ReportingLimits): ReportDefinition {
  const object = expectObject(value, path)
  exactKeys(
    object,
    [
      "schema_version",
      "id",
      "title",
      "description",
      "panels",
      "layout",
      "parameters",
      "provenance",
    ],
    path,
    ["id", "parameters"],
  )
  const schemaVersion = expectString(object.schema_version, [...path, "schema_version"], 16)
  if (!/^1\.\d+$/.test(schemaVersion))
    fail(
      "unsupported_schema_version",
      [...path, "schema_version"],
      "Only schema major 1 is supported",
    )

  const rawPanels = expectArray(object.panels, [...path, "panels"])
  if (rawPanels.length > limits.maxPanels)
    fail("limit_exceeded", [...path, "panels"], "Too many panels")
  const panels = rawPanels.map((panel, index) => decodePanel(panel, [...path, "panels", index]))
  unique(
    panels.map((panel) => panel.id),
    [...path, "panels"],
    "panel id",
  )

  return {
    schema_version: schemaVersion,
    id:
      object.id === undefined || object.id === null
        ? null
        : expectString(object.id, [...path, "id"], 256),
    title: expectString(object.title, [...path, "title"], 512),
    description: expectString(object.description, [...path, "description"], 4_096),
    panels,
    layout: expectObject(object.layout, [...path, "layout"]),
    parameters:
      object.parameters === undefined
        ? []
        : expectArray(object.parameters, [...path, "parameters"]),
    provenance: expectObject(object.provenance, [...path, "provenance"]),
  }
}

function decodePanel(value: unknown, path: Path): PanelDefinition {
  const object = expectObject(value, path)
  exactKeys(
    object,
    ["id", "title", "description", "query_ref", "visualization", "table_columns", "empty_message"],
    path,
  )
  return {
    id: expectIdentifier(object.id, [...path, "id"]),
    title: expectString(object.title, [...path, "title"], 512),
    description: expectString(object.description, [...path, "description"], 4_096),
    query_ref: expectString(object.query_ref, [...path, "query_ref"], 1_024),
    visualization: decodeVisualization(object.visualization, [...path, "visualization"]),
    table_columns: expectArray(object.table_columns, [...path, "table_columns"]).map(
      (field, index) => expectIdentifier(field, [...path, "table_columns", index]),
    ),
    empty_message: expectString(object.empty_message, [...path, "empty_message"], 1_024),
  }
}

function decodeVisualization(value: unknown, path: Path): VisualizationDefinition {
  const object = expectObject(value, path)
  exactKeys(
    object,
    [
      "kind",
      "encodings",
      "formats",
      "sort",
      "stack",
      "annotations",
      "interaction",
      "summary_template",
    ],
    path,
    ["formats", "sort", "stack", "annotations", "interaction"],
  )
  const rawEncodings = expectObject(object.encodings, [...path, "encodings"])
  exactKeys(
    rawEncodings,
    ["x", "y", "series", "value", "label", "color_group", "size"],
    [...path, "encodings"],
    ["x", "y", "series", "value", "label", "color_group", "size"],
  )
  const encodings: VisualizationDefinition["encodings"] = {}
  for (const [channel, field] of Object.entries(rawEncodings))
    encodings[channel as keyof typeof encodings] = expectIdentifier(field, [
      ...path,
      "encodings",
      channel,
    ])

  const sort =
    object.sort === undefined
      ? []
      : expectArray(object.sort, [...path, "sort"]).map((entry, index) => {
          const item = expectObject(entry, [...path, "sort", index])
          exactKeys(item, ["field", "direction"], [...path, "sort", index])
          return {
            field: expectIdentifier(item.field, [...path, "sort", index, "field"]),
            direction: expectEnum(item.direction, ["asc", "desc"] as const, [
              ...path,
              "sort",
              index,
              "direction",
            ]),
          }
        })

  const annotations =
    object.annotations === undefined
      ? []
      : expectArray(object.annotations, [...path, "annotations"]).map((entry, index) => {
          const item = expectObject(entry, [...path, "annotations", index])
          exactKeys(item, ["text", "field"], [...path, "annotations", index], ["field"])
          return {
            text: expectString(item.text, [...path, "annotations", index, "text"], 1_024),
            ...(item.field === undefined
              ? {}
              : { field: expectIdentifier(item.field, [...path, "annotations", index, "field"]) }),
          }
        })

  const interaction =
    object.interaction === undefined
      ? {}
      : expectObject(object.interaction, [...path, "interaction"])
  exactKeys(
    interaction,
    ["selection", "drill_action_id"],
    [...path, "interaction"],
    ["selection", "drill_action_id"],
  )

  return {
    kind: expectEnum(object.kind, VISUALIZATION_KINDS, [...path, "kind"]),
    encodings,
    formats: object.formats === undefined ? {} : expectObject(object.formats, [...path, "formats"]),
    sort,
    stack:
      object.stack === undefined
        ? "none"
        : expectEnum(object.stack, ["none", "normal", "normalized"] as const, [...path, "stack"]),
    annotations,
    interaction: {
      ...(interaction.selection === undefined
        ? {}
        : {
            selection: expectEnum(interaction.selection, ["none", "point", "interval"] as const, [
              ...path,
              "interaction",
              "selection",
            ]),
          }),
      ...(interaction.drill_action_id === undefined
        ? {}
        : {
            drill_action_id: expectIdentifier(interaction.drill_action_id, [
              ...path,
              "interaction",
              "drill_action_id",
            ]),
          }),
    },
    summary_template: expectString(object.summary_template, [...path, "summary_template"], 2_048),
  }
}

function decodePanelResult(value: unknown, path: Path, limits: ReportingLimits): PanelResult {
  const object = expectObject(value, path)
  const state = expectEnum(object.state, PANEL_STATES, [...path, "state"])
  if (state === "ok" || state === "partial") {
    exactKeys(object, ["state", "frame"], path)
    return { state, frame: decodeFrame(object.frame, [...path, "frame"], limits) }
  }
  exactKeys(object, ["state", "detail"], path, ["detail"])
  return { state, ...(object.detail === undefined ? {} : { detail: object.detail }) }
}

function decodeFrame(value: unknown, path: Path, limits: ReportingLimits): ResultFrame {
  const object = expectObject(value, path)
  exactKeys(object, ["fields", "rows", "provenance", "freshness", "classification", "page"], path)
  const rawFields = expectArray(object.fields, [...path, "fields"])
  if (rawFields.length > limits.maxFields)
    fail("limit_exceeded", [...path, "fields"], "Too many fields")
  const fields = rawFields.map((field, index) => decodeField(field, [...path, "fields", index]))
  unique(
    fields.map((field) => field.name),
    [...path, "fields"],
    "field name",
  )
  const rows = expectArray(object.rows, [...path, "rows"])
  if (rows.length > limits.maxRows) fail("limit_exceeded", [...path, "rows"], "Too many rows")
  const decodedRows = rows.map((row, rowIndex) =>
    decodeRow(row, fields, [...path, "rows", rowIndex], limits),
  )
  return {
    fields,
    rows: decodedRows,
    provenance: expectObject(object.provenance, [...path, "provenance"]),
    freshness: expectObject(object.freshness, [...path, "freshness"]),
    classification: expectObject(object.classification, [...path, "classification"]),
    page: expectObject(object.page, [...path, "page"]),
  }
}

function decodeField(value: unknown, path: Path): ResultField {
  const object = expectObject(value, path)
  exactKeys(object, ["name", "label", "type", "role", "unit", "nullable", "classification"], path, [
    "unit",
  ])
  return {
    name: expectIdentifier(object.name, [...path, "name"]),
    label: expectString(object.label, [...path, "label"], 512),
    type: expectEnum(object.type, FIELD_TYPES, [...path, "type"]),
    role: expectEnum(object.role, FIELD_ROLES, [...path, "role"]),
    unit:
      object.unit === undefined || object.unit === null
        ? null
        : expectString(object.unit, [...path, "unit"], 128),
    nullable: expectBoolean(object.nullable, [...path, "nullable"]),
    classification: expectEnum(object.classification, CLASSIFICATIONS, [...path, "classification"]),
  }
}

function decodeRow(
  value: unknown,
  fields: ResultField[],
  path: Path,
  limits: ReportingLimits,
): unknown[] {
  const row = expectArray(value, path)
  if (row.length !== fields.length)
    fail("row_width_mismatch", path, "Row width differs from field schema")
  return row.map((cell, index) => {
    const field = fields[index]
    if (!field) return fail("row_width_mismatch", path, "Row width differs from field schema")
    return validateCell(cell, field, [...path, index], limits)
  })
}

function validateCell(
  value: unknown,
  field: ResultField,
  path: Path,
  limits: ReportingLimits,
): unknown {
  if (value === null) {
    if (field.nullable) return null
    return fail("invalid_cell", path, "Null is not allowed")
  }
  if (typeof value === "string" && encoder.encode(value).byteLength > limits.maxCellBytes)
    fail("limit_exceeded", path, "String cell is too large")
  const valid =
    field.type === "boolean"
      ? typeof value === "boolean"
      : field.type === "integer" || field.type === "duration"
        ? Number.isSafeInteger(value)
        : field.type === "float"
          ? typeof value === "number" && Number.isFinite(value)
          : field.type === "decimal"
            ? typeof value === "string" && DECIMAL.test(value)
            : field.type === "date"
              ? typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)
              : field.type === "time"
                ? typeof value === "string" && /^\d{2}:\d{2}:\d{2}(?:\.\d+)?$/.test(value)
                : field.type === "datetime"
                  ? typeof value === "string" && !Number.isNaN(Date.parse(value))
                  : typeof value === "string"
  if (!valid) fail("invalid_cell", path, `Value does not match ${field.type}`)
  return value
}

function validateBindings(panel: PanelDefinition, frame: ResultFrame): void {
  const fields = new Map(frame.fields.map((field) => [field.name, field]))
  const references = [
    ...Object.values(panel.visualization.encodings),
    ...panel.table_columns,
    ...panel.visualization.sort.map((sort) => sort.field),
  ]
  for (const reference of references)
    if (reference !== undefined && !fields.has(reference))
      fail("unknown_field", ["definition", "panels", panel.id], `Unknown field ${reference}`)
  for (const channel of ["x", "y", "value", "size"] as const) {
    const fieldName = panel.visualization.encodings[channel]
    if (fieldName && fields.get(fieldName)?.role === "identifier")
      fail(
        "invalid_encoding",
        ["definition", "panels", panel.id, "visualization", "encodings", channel],
        "Identifier cannot use a quantitative channel",
      )
  }
}

function expectObject(value: unknown, path: Path): JsonObject {
  if (value === null || typeof value !== "object" || Array.isArray(value))
    return fail("expected_object", path, "Expected an object")
  return value as JsonObject
}

function expectArray(value: unknown, path: Path): unknown[] {
  if (!Array.isArray(value)) return fail("expected_array", path, "Expected an array")
  return value
}

function expectString(value: unknown, path: Path, maxBytes: number): string {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    encoder.encode(value).byteLength > maxBytes
  )
    return fail("invalid_string", path, "Expected a bounded non-empty string")
  return value
}

function expectIdentifier(value: unknown, path: Path): string {
  const identifier = expectString(value, path, 256)
  if (!IDENTIFIER.test(identifier))
    fail("invalid_identifier", path, "Expected a portable identifier")
  return identifier
}

function expectBoolean(value: unknown, path: Path): boolean {
  if (typeof value !== "boolean") return fail("expected_boolean", path, "Expected a boolean")
  return value
}

function expectDateTime(value: unknown, path: Path): string {
  const dateTime = expectString(value, path, 64)
  if (Number.isNaN(Date.parse(dateTime)))
    fail("invalid_datetime", path, "Expected an RFC 3339 datetime")
  return dateTime
}

function expectEnum<const T extends readonly string[]>(
  value: unknown,
  allowed: T,
  path: Path,
): T[number] {
  if (typeof value !== "string" || !allowed.includes(value))
    return fail("invalid_enum", path, `Expected one of ${allowed.join(", ")}`)
  return value as T[number]
}

function exactKeys(
  object: JsonObject,
  allowed: string[],
  path: Path,
  optional: string[] = [],
): void {
  const unknown = Object.keys(object)
    .filter((key) => !allowed.includes(key))
    .sort()
  if (unknown.length > 0) fail("unknown_keys", path, `Unknown keys: ${unknown.join(", ")}`)
  const required = allowed.filter((key) => !optional.includes(key))
  const missing = required.filter((key) => !Object.hasOwn(object, key)).sort()
  if (missing.length > 0) fail("missing_keys", path, `Missing keys: ${missing.join(", ")}`)
}

function unique(values: string[], path: Path, label: string): void {
  if (new Set(values).size !== values.length) fail("duplicate", path, `Duplicate ${label}`)
}

function fail(code: string, path: Path, message: string): never {
  throw new ReportingContractError(code, path, message)
}

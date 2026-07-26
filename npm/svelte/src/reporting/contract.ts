export const VISUALIZATION_KINDS = [
  "number",
  "table",
  "line",
  "area",
  "bar",
  "scatter",
  "heatmap",
  "gauge",
  "sparkline",
] as const

export const FIELD_TYPES = [
  "boolean",
  "integer",
  "float",
  "decimal",
  "string",
  "date",
  "time",
  "datetime",
  "duration",
] as const

export const FIELD_ROLES = ["dimension", "measure", "time", "identifier"] as const
export const CLASSIFICATIONS = ["public", "internal", "confidential", "restricted"] as const
export const PANEL_STATES = ["ok", "empty", "partial", "error"] as const

export type VisualizationKind = (typeof VISUALIZATION_KINDS)[number]
export type FieldType = (typeof FIELD_TYPES)[number]
export type FieldRole = (typeof FIELD_ROLES)[number]
export type Classification = (typeof CLASSIFICATIONS)[number]
export type PanelState = (typeof PANEL_STATES)[number]

export type ResultField = {
  name: string
  label: string
  type: FieldType
  role: FieldRole
  unit: string | null
  nullable: boolean
  classification: Classification
}

export type ResultFrame = {
  fields: ResultField[]
  rows: unknown[][]
  provenance: Record<string, unknown>
  freshness: Record<string, unknown>
  classification: Record<string, unknown>
  page: Record<string, unknown>
}

export type VisualizationDefinition = {
  kind: VisualizationKind
  encodings: Partial<
    Record<"x" | "y" | "series" | "value" | "label" | "color_group" | "size", string>
  >
  formats: Record<string, string>
  sort: Array<{ field: string; direction: "asc" | "desc" }>
  stack: "none" | "normal" | "normalized"
  annotations: Array<{ text: string; field?: string }>
  interaction: { selection?: "none" | "point" | "interval"; drill_action_id?: string }
  summary_template: string
}

export type PanelDefinition = {
  id: string
  title: string
  description: string
  query_ref: string
  visualization: VisualizationDefinition
  table_columns: string[]
  empty_message: string
}

export type ReportLayout = {
  columns?: number
  order?: string[]
  spans?: Record<string, number>
}

export type ReportingMessages = {
  accessibleFallback: string
  viewTable: string
  hideTable: string
  panelUnavailable: string
  partialResult: string
  chartUnavailable: string
  stateLabel: string
  watermarkLabel: string
  truncatedLabel: string
  drillRow: string
  previousPage: string
  nextPage: string
  pageStatus: (page: number, pages: number) => string
  tableRegion: (caption: string) => string
  noRows: string
}

export const DEFAULT_REPORTING_MESSAGES: ReportingMessages = {
  accessibleFallback: "Some panels use an accessible fallback on this device.",
  viewTable: "View as table",
  hideTable: "Hide table",
  panelUnavailable: "This panel is unavailable.",
  partialResult: "This result is partial. Review its evidence before use.",
  chartUnavailable: "A safe chart is unavailable; the complete table is shown.",
  stateLabel: "State",
  watermarkLabel: "Watermark",
  truncatedLabel: "Truncated",
  drillRow: "Open details",
  previousPage: "Previous page",
  nextPage: "Next page",
  pageStatus: (page, pages) => `Page ${page} of ${pages}`,
  tableRegion: (caption) => `${caption} data table`,
  noRows: "No rows",
}

export type ReportDefinition = {
  schema_version: string
  id: string | null
  title: string
  description: string
  panels: PanelDefinition[]
  layout: ReportLayout
  parameters: unknown[]
  provenance: Record<string, unknown>
}

export type PanelResult =
  | { state: "ok" | "partial"; frame: ResultFrame }
  | { state: "empty" | "error"; detail?: unknown }

export type ReportEnvelope = {
  definition: ReportDefinition
  results: Record<string, PanelResult>
  capability_warnings: Array<Record<string, unknown>>
  generated_at: string
}

export type ReportingLimits = {
  maxBytes: number
  maxPanels: number
  maxFields: number
  maxRows: number
  maxCellBytes: number
  maxDepth: number
}

export const DEFAULT_REPORTING_LIMITS: ReportingLimits = {
  maxBytes: 262_144,
  maxPanels: 32,
  maxFields: 64,
  maxRows: 10_000,
  maxCellBytes: 8_192,
  maxDepth: 64,
}

export class ReportingContractError extends Error {
  readonly path: ReadonlyArray<string | number>
  readonly code: string

  constructor(code: string, path: ReadonlyArray<string | number>, message: string) {
    super(message)
    this.name = "ReportingContractError"
    this.code = code
    this.path = path
  }
}

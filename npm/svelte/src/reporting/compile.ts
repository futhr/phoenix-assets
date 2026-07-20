import type { PanelDefinition, ResultField, ResultFrame, VisualizationKind } from "./contract.js"

export type ChartDatum = Record<string, boolean | number | string | null>

export type CompiledPanel = {
  kind: VisualizationKind
  data: ChartDatum[]
  fields: Map<string, ResultField>
  x?: string
  y?: string
  series?: string
  seriesValues: string[]
  value?: string
  chartable: boolean
  fallbackReason?: "insufficient_data" | "missing_encoding" | "unsafe_numeric_value"
}

export function compilePanel(panel: PanelDefinition, frame: ResultFrame): CompiledPanel {
  const fields = new Map(frame.fields.map((field) => [field.name, field]))
  const data = frame.rows.map((row) =>
    Object.fromEntries(
      frame.fields.map((field, index) => [field.name, chartValue(row[index], field)]),
    ),
  )
  const { x, y, series, value } = panel.visualization.encodings
  const required = requiredEncodings(panel.visualization.kind)
  const missing = required.some((channel) => panel.visualization.encodings[channel] === undefined)
  const unsafe = data.some((datum) =>
    [...required, "series" as const].some((channel) => {
      const field = panel.visualization.encodings[channel]
      return field !== undefined && datum[field] === Number.POSITIVE_INFINITY
    }),
  )
  const insufficient =
    ["line", "area", "sparkline"].includes(panel.visualization.kind) && data.length < 2

  return {
    kind: panel.visualization.kind,
    data,
    fields,
    x,
    y,
    series,
    seriesValues:
      series === undefined ? [] : [...new Set(data.map((datum) => String(datum[series])))],
    value,
    chartable: !missing && !unsafe && !insufficient,
    ...(missing ? { fallbackReason: "missing_encoding" as const } : {}),
    ...(unsafe ? { fallbackReason: "unsafe_numeric_value" as const } : {}),
    ...(insufficient ? { fallbackReason: "insufficient_data" as const } : {}),
  }
}

function requiredEncodings(kind: VisualizationKind): Array<"x" | "y" | "value"> {
  if (kind === "number" || kind === "gauge") return ["value"]
  if (kind === "table") return []
  if (kind === "heatmap") return ["x", "y", "value"]
  return ["x", "y"]
}

function chartValue(value: unknown, field: ResultField): boolean | number | string | null {
  if (value === null) return null
  if (field.type === "datetime" || field.type === "date" || field.type === "time")
    return value as string
  if (field.type === "decimal") {
    const number = Number(value)
    const significantDigits = String(value)
      .replace("-", "")
      .replace(".", "")
      .replace(/^0+/, "").length
    return Number.isFinite(number) &&
      Math.abs(number) <= Number.MAX_SAFE_INTEGER &&
      significantDigits <= 15
      ? number
      : Number.POSITIVE_INFINITY
  }
  return value as boolean | number | string
}

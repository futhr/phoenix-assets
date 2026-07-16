import type { ResultField } from "./contract.js"

export function formatCell(value: unknown, field: ResultField, locale?: string): string {
  if (value === null) return "—"
  if (field.type === "boolean") return value ? "Yes" : "No"
  if (field.type === "integer" || field.type === "float")
    return formatNumber(value as number, field.unit, locale)
  if (field.type === "decimal") return appendUnit(value as string, field.unit)
  if (field.type === "duration") return appendUnit(String(value), field.unit)
  return String(value)
}

function formatNumber(value: number, unit: string | null, locale?: string): string {
  if (unit && /^[A-Z]{3}$/.test(unit)) {
    return new Intl.NumberFormat(locale, { style: "currency", currency: unit }).format(value)
  }
  if (unit === "percent")
    return new Intl.NumberFormat(locale, { style: "percent" }).format(value / 100)
  return appendUnit(new Intl.NumberFormat(locale).format(value), unit)
}

function appendUnit(value: string, unit: string | null): string {
  return unit === null || unit === "count" ? value : `${value} ${unit}`
}

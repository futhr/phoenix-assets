import type { PanelDefinition, VisualizationDefinition, VisualizationKind } from "./contract.js"

/**
 * Builds a panel in the browser, for a chart the client composes rather than
 * one that arrived over the wire.
 *
 * There are two doors into this package and they are not equally strict, which
 * was true before this file existed but written down nowhere:
 *
 * - `decodeReportEnvelope` is the **wire boundary**. Untrusted input, every
 *   field validated, unknown keys rejected. A panel that reaches a user's
 *   browser from a server goes through it.
 * - `PortablePanel` takes a `PanelDefinition` value and renders it. It performs
 *   no runtime validation, because by then the value is the app's own.
 *
 * A locally composed chart has no wire form and no `query_ref` — the app already
 * has the frame. That is legitimate, but hand-building the struct means an app
 * silently depends on the second door's looseness, and hosts were doing it with
 * their own helpers. This makes it a supported path with a name.
 *
 * The result is deliberately **not** wire-valid: `query_ref` is empty, which the
 * decoder rejects. Do not send it anywhere; if a panel needs to travel, the
 * owning domain issues it.
 */
export type ComposePanelOptions = {
  title: string
  kind: VisualizationKind
  encodings: VisualizationDefinition["encodings"]
  /** Defaults to a slug of the title. */
  id?: string
  description?: string
  formats?: VisualizationDefinition["formats"]
  sort?: VisualizationDefinition["sort"]
  stack?: VisualizationDefinition["stack"]
  /** Accessible table twin. Defaults to every encoded field, in channel order. */
  tableColumns?: string[]
  emptyMessage?: string
  /** Plain-text purpose. Defaults to the title. */
  summary?: string
}

const slug = (value: string): string =>
  value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "panel"

// A chart with no table twin is unreadable to anyone not looking at it, and the
// upstream contract requires a renderer to be able to fall back to one. Deriving
// the columns from the encodings means the default is never "none".
const encodedFields = (encodings: VisualizationDefinition["encodings"]): string[] => [
  ...new Set(Object.values(encodings).filter((field): field is string => Boolean(field))),
]

export function composePanel(options: ComposePanelOptions): PanelDefinition {
  return {
    id: options.id ?? slug(options.title),
    title: options.title,
    description: options.description ?? "",
    query_ref: "",
    visualization: {
      kind: options.kind,
      encodings: options.encodings,
      formats: options.formats ?? {},
      sort: options.sort ?? [],
      stack: options.stack ?? "none",
      annotations: [],
      interaction: {},
      summary_template: options.summary ?? options.title,
    },
    table_columns: options.tableColumns ?? encodedFields(options.encodings),
    empty_message: options.emptyMessage ?? "No data available.",
  }
}

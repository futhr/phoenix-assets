// The `doc-shell/v1` contract, as its producers actually emit it. Two exist and
// they do not agree on every key: `doc_shell`'s StaticGenerator emits `kind`,
// `meta`, and `tokens`; a host's GraphProjector emits none of the three. A field
// only one producer sends is therefore optional here — that is the contract, not
// an oversight. Keys both producers always send stay required, even when the
// value is null.
//
// `test/conformance.test.ts` holds both producers' real output against these
// types. Move one side without the other and it fails.

export type DocAstNode = string | DocAstElement

export interface DocAstElement {
  tag: string
  attrs?: Record<string, string>
  content?: DocAstNode[] | string
  /** Parser metadata (source line, and so on). Opaque to the renderer. */
  meta?: Record<string, unknown>
}

export interface NavigationItem {
  id: string
  title: string
  path: string
  children?: NavigationItem[]
  /** Entry class, e.g. `"module"` or `"guide"`. StaticGenerator only. */
  kind?: string | null
  /** Producer-defined extras. StaticGenerator only; opaque to the renderer. */
  meta?: Record<string, unknown>
}

export interface SearchEntry {
  id: string
  title: string
  content: string
  path: string
  /** Null when the producer does not scope entries by audience. */
  audience: string | null
  /** Null when the producer does not scope entries by locale. */
  locale: string | null
  /** Entry class, mirroring `NavigationItem.kind`. StaticGenerator only. */
  kind?: string | null
  /**
   * Pre-split content tokens. StaticGenerator only, and nothing here reads
   * them — `search.svelte` indexes `title` and `content` through Fuse. Declared
   * so the type describes the payload honestly; a producer may omit them.
   */
  tokens?: string[]
}

export interface Backlink {
  id: string
  title: string
  path: string
}

export interface DocShellPresentation {
  schema_version: "doc-shell/v1"
  navigation: NavigationItem[]
  search: SearchEntry[]
  content: Record<string, DocAstNode[]>
  backlinks?: Record<string, Backlink[]>
}

export type PresentationSource = () => DocShellPresentation | Promise<DocShellPresentation>

export interface DocShellTheme {
  accent?: string
  background?: string
  border?: string
  foreground?: string
  muted?: string
  radius?: string
}

export interface JsonSchema {
  /**
   * OpenAPI 3.0 writes a single type plus `nullable`; 3.1 writes a JSON Schema
   * type array, `["string", "null"]`. AshOaskit emits both dialects, so both
   * shapes reach `typeLabel`.
   */
  type?: string | string[]
  format?: string
  description?: string
  enum?: unknown[]
  items?: JsonSchema
  properties?: Record<string, JsonSchema>
  required?: string[]
  oneOf?: JsonSchema[]
  anyOf?: JsonSchema[]
  allOf?: JsonSchema[]
  nullable?: boolean
  example?: unknown
}

export interface Operation {
  operationId?: string
  summary?: string
  description?: string
  tags?: string[]
  parameters?: Array<{ name: string; in: string; required?: boolean; description?: string }>
  requestBody?: { content?: Record<string, { schema?: JsonSchema }> }
  responses?: Record<
    string,
    { description?: string; content?: Record<string, { schema?: JsonSchema }> }
  >
}

export interface OpenApiDocument {
  info?: { title?: string; version?: string; description?: string }
  paths?: Record<
    string,
    Partial<Record<"get" | "post" | "put" | "patch" | "delete" | "options" | "head", Operation>>
  >
}

export interface OperationEntry {
  id: string
  method: string
  path: string
  tags: string[]
  operation: Operation
}

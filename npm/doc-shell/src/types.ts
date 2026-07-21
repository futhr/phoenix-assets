export type DocAstNode = string | DocAstElement

export interface DocAstElement {
  tag: string
  attrs?: Record<string, string>
  content?: DocAstNode[] | string
}

export interface NavigationItem {
  id: string
  title: string
  path: string
  children?: NavigationItem[]
}

export interface SearchEntry {
  id: string
  title: string
  content: string
  path: string
  audience?: string
  locale?: string
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
  type?: string
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

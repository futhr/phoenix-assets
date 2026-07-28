import type { JsonSchema, OpenApiDocument, OperationEntry } from "./types.js"

const methods = ["get", "post", "put", "patch", "delete", "options", "head"] as const

export const flattenOperations = (spec: OpenApiDocument): OperationEntry[] =>
  Object.entries(spec.paths ?? {}).flatMap(([path, item]) =>
    methods.flatMap((method) => {
      const operation = item[method]
      if (!operation) return []
      return [
        {
          id: operation.operationId ?? `${method}-${path}`,
          method: method.toUpperCase(),
          path,
          tags: operation.tags?.length ? operation.tags : ["default"],
          operation,
        },
      ]
    }),
  )

export const groupOperations = (operations: OperationEntry[]): Record<string, OperationEntry[]> => {
  const groups: Record<string, OperationEntry[]> = {}
  for (const entry of operations) {
    const tag = entry.tags[0] ?? "default"
    groups[tag] = [...(groups[tag] ?? []), entry]
  }
  return groups
}

export const schemaFrom = (
  content?: Record<string, { schema?: JsonSchema }>,
): JsonSchema | undefined =>
  content?.["application/json"]?.schema ?? content?.["application/vnd.api+json"]?.schema

/**
 * Splits a schema's type into its non-null names and whether null is allowed,
 * across both OpenAPI dialects: 3.0's `{type, nullable}` and 3.1's type array.
 */
const typeOf = (schema: JsonSchema): { names: string[]; nullable: boolean } => {
  const declared = Array.isArray(schema.type) ? schema.type : schema.type ? [schema.type] : []
  const names = declared.filter((name) => name !== "null")
  return { names, nullable: schema.nullable === true || declared.includes("null") }
}

export const typeLabel = (schema: JsonSchema): string => {
  if (schema.oneOf) return "oneOf"
  if (schema.anyOf) return "anyOf"
  if (schema.allOf) return "allOf"

  const { names, nullable } = typeOf(schema)
  const label = names.includes("array")
    ? `${schema.items ? (typeOf(schema.items).names[0] ?? "object") : "object"}[]`
    : names.join(" | ") || "object"

  return nullable ? `${label}?` : label
}

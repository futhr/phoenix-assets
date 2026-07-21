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

export const typeLabel = (schema: JsonSchema): string => {
  if (schema.oneOf) return "oneOf"
  if (schema.anyOf) return "anyOf"
  if (schema.allOf) return "allOf"
  const type =
    schema.type === "array" ? `${schema.items?.type ?? "object"}[]` : (schema.type ?? "object")
  return schema.nullable ? `${type}?` : type
}

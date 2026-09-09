import type { Row } from "@electric-sql/client"
import { electricCollectionOptions } from "@tanstack/electric-db-collection"
import { createCollection } from "@tanstack/svelte-db"
import { shapeParser } from "./parser.js"
import { type AuthConfig, createShapeFetch, createShapeUrl } from "./url.js"

/**
 * A TanStack DB collection backed by an ElectricSQL shape.
 *
 * Use this (rather than `createShapeStore`) when a component needs cross-shape
 * joins, the query DSL, or optimistic-write reconciliation. Generalised from the
 * pattern Phoenix apps repeat; type it with a row type from `$phoenix/types`.
 */
export function createShapeCollection<TRow extends Row<unknown> & { id: string | number }>(
  path: string,
  params: Record<string, string | number> = {},
  config: AuthConfig = {},
) {
  return createCollection(
    electricCollectionOptions<TRow>({
      shapeOptions: {
        url: createShapeUrl(path, params),
        fetchClient: createShapeFetch(config),
        parser: shapeParser,
      },
      getKey: (row) => row.id,
    }),
  )
}

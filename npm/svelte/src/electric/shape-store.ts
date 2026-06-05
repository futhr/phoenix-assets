import { type Row, Shape, ShapeStream } from "@electric-sql/client"
import { createSubscriber } from "svelte/reactivity"
import { type AuthConfig, authHeaders, createShapeUrl } from "./url"

/**
 * A reactive view of an ElectricSQL shape, idiomatic for Svelte 5.
 *
 * Reading `.rows` inside a reactive context (a component, `$derived`, or
 * `$effect`) subscribes a `Shape` over a `ShapeStream`; when the last reader
 * stops observing, the subscription tears itself down. This is the rune-era
 * equivalent of the `svelte/store` `readable` Phoenix apps hand-roll -- same
 * auto-managed lifecycle, built on `createSubscriber`, so consumers read
 * `store.rows` rather than `$store`.
 *
 * `path` may be a thunk (resolved when the subscription starts). Type it with a
 * row type from `$phoenix/types` for end-to-end safety.
 */
export interface ShapeStore<T extends Row<unknown>> {
  readonly rows: T[]
}

export function createShapeStore<T extends Row<unknown>>(
  path: string | (() => string),
  params: Record<string, string | number> = {},
  config: AuthConfig = {},
): ShapeStore<T> {
  let shape: Shape<T> | undefined

  const subscribe = createSubscriber((update) => {
    const resolved = typeof path === "function" ? path() : path
    const stream = new ShapeStream<T>({
      url: createShapeUrl(resolved, params),
      headers: authHeaders(config),
    })

    shape = new Shape(stream)
    const unsubscribe = shape.subscribe(() => update())

    return () => {
      unsubscribe()
      shape = undefined
    }
  })

  return {
    get rows() {
      subscribe()
      return shape?.currentRows ?? []
    },
  }
}

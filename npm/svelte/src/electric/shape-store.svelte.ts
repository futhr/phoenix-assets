import { type Row, Shape, ShapeStream } from "@electric-sql/client"
import { createSubscriber } from "svelte/reactivity"
import { type AuthConfig, authHeaders, createShapeUrl } from "./url.js"

/** Where a shape subscription is in its lifecycle. */
export type ShapeStatus = "loading" | "ready" | "error"

/**
 * A reactive view of an ElectricSQL shape, idiomatic for Svelte 5.
 *
 * Reading `.rows` inside a reactive context (a component, `$derived`, or
 * `$effect`) subscribes a `Shape` over a `ShapeStream`; when the last reader
 * stops observing, the subscription tears itself down. Consumers read
 * `store.rows` rather than `$store`.
 *
 * `status` and `error` exist because a sync surface that can only say "here are
 * the rows" leaves an empty result indistinguishable from a failed one — and
 * every app then rebuilds the same three-state wrapper around it.
 */
export interface ShapeStore<T extends Row<unknown>> {
  readonly rows: T[]
  readonly status: ShapeStatus
  readonly error: Error | null
  /** Tears the current subscription down and starts a fresh one. */
  retry(): void
}

/** A {@link ShapeStore} that also applies writes optimistically. */
export interface MutableShapeStore<T extends Row<unknown>> extends ShapeStore<T> {
  insert(row: T): Promise<void>
  update(id: string, changes: Partial<T>): Promise<void>
  remove(id: string): Promise<void>
}

/** Server writes behind {@link createMutableShapeStore}'s optimistic updates. */
export interface ShapeMutations<T extends Row<unknown>> {
  onInsert?: (row: T) => Promise<unknown>
  onUpdate?: (id: string, changes: Partial<T>) => Promise<unknown>
  onRemove?: (id: string) => Promise<unknown>
  /** Row identity. Defaults to `row.id`. */
  identify?: (row: T) => string
}

const toError = (cause: unknown): Error =>
  cause instanceof Error ? cause : new Error(String(cause))

export function createShapeStore<T extends Row<unknown>>(
  path: string | (() => string),
  params: Record<string, string | number> = {},
  config: AuthConfig = {},
): ShapeStore<T> {
  let shape: Shape<T> | undefined
  let status = $state<ShapeStatus>("loading")
  let error = $state<Error | null>(null)
  // Read inside the subscriber and bumped by retry(), so a retry invalidates
  // the subscription and createSubscriber sets a fresh one up.
  let generation = $state(0)

  const subscribe = createSubscriber((update) => {
    void generation
    const resolved = typeof path === "function" ? path() : path
    const controller = new AbortController()
    const stream = new ShapeStream<T>({
      url: createShapeUrl(resolved, params),
      headers: authHeaders(config),
      signal: controller.signal,
      // Electric already retries 5xx, network errors, and 429 with backoff; this
      // fires for what it will not retry. Returning nothing stops syncing, which
      // is what `status: "error"` then reports and `retry()` undoes.
      onError: (streamError) => {
        status = "error"
        error = toError(streamError)
        update()
      },
    })

    const current = new Shape(stream)
    shape = current
    status = "loading"
    error = null

    // `Shape.subscribe` reports data only, so a failed fetch also has to be read
    // off the shape — otherwise an errored sync is indistinguishable from an
    // empty one, which is the whole reason `status` exists.
    const unsubscribe = current.subscribe(() => {
      const failure = current.error
      status = failure ? "error" : "ready"
      error = failure ? toError(failure) : null
      update()
    })

    return () => {
      unsubscribe()
      controller.abort()
      stream.unsubscribeAll()
      shape = undefined
    }
  })

  return {
    get rows() {
      subscribe()
      return shape?.currentRows ?? []
    },
    get status() {
      subscribe()
      return status
    },
    get error() {
      subscribe()
      return error
    },
    retry() {
      generation += 1
    },
  }
}

/**
 * A shape store whose writes show up before the server confirms them.
 *
 * The optimistic rows are applied locally, the handler runs, and a rejection
 * puts the previous rows back and surfaces the error. Electric's own sync
 * overwrites the optimistic state once the change round-trips, so the local
 * overlay only has to cover the gap in between.
 */
export function createMutableShapeStore<T extends Row<unknown>>(
  path: string | (() => string),
  mutations: ShapeMutations<T> = {},
  params: Record<string, string | number> = {},
  config: AuthConfig = {},
): MutableShapeStore<T> {
  const store = createShapeStore<T>(path, params, config)
  const identify = mutations.identify ?? ((row: T) => String((row as { id?: unknown }).id))

  // null means "no local overlay" — read straight through to the synced rows.
  let overlay = $state<T[] | null>(null)
  let mutationError = $state<Error | null>(null)

  const current = () => overlay ?? store.rows

  const apply = async (next: T[], write: () => Promise<unknown>) => {
    const previous = current()
    overlay = next
    mutationError = null

    try {
      await write()
      // Drop the overlay and let Electric's sync be the truth again.
      overlay = null
    } catch (cause) {
      overlay = previous
      mutationError = cause instanceof Error ? cause : new Error(String(cause))
      throw mutationError
    }
  }

  return {
    get rows() {
      return current()
    },
    get status() {
      return store.status
    },
    get error() {
      return mutationError ?? store.error
    },
    retry() {
      overlay = null
      mutationError = null
      store.retry()
    },
    insert(row) {
      return apply([...current(), row], () => mutations.onInsert?.(row) ?? Promise.resolve())
    },
    update(id, changes) {
      const next = current().map((row) => (identify(row) === id ? { ...row, ...changes } : row))
      return apply(next, () => mutations.onUpdate?.(id, changes) ?? Promise.resolve())
    },
    remove(id) {
      const next = current().filter((row) => identify(row) !== id)
      return apply(next, () => mutations.onRemove?.(id) ?? Promise.resolve())
    },
  }
}

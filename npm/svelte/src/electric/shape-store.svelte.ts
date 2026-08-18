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

interface OptimisticMutation<T> {
  id: number
  pending: boolean
  patch: (rows: T[]) => T[]
}

interface QueuedWrite {
  id: number
  run: () => Promise<unknown>
  resolve: () => void
  reject: (error: Error) => void
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
 * Each optimistic change is replayed over Electric's latest rows in issue
 * order. Server writes are serialized in that same order: a slow older write
 * cannot clear or roll back a newer optimistic change, while an Electric sync
 * arriving between writes becomes the new base for every pending patch.
 */
export function createMutableShapeStore<T extends Row<unknown>>(
  path: string | (() => string),
  mutations: ShapeMutations<T> = {},
  params: Record<string, string | number> = {},
  config: AuthConfig = {},
): MutableShapeStore<T> {
  const store = createShapeStore<T>(path, params, config)
  const identify = mutations.identify ?? ((row: T) => String((row as { id?: unknown }).id))

  let optimistic = $state<OptimisticMutation<T>[]>([])
  let mutationError = $state<Error | null>(null)
  let nextMutationId = 0
  const writeQueue: QueuedWrite[] = []
  let writing = false

  const current = () => optimistic.reduce((rows, mutation) => mutation.patch(rows), store.rows)

  const settleSuccess = (id: number) => {
    optimistic = optimistic.map((mutation) =>
      mutation.id === id ? { ...mutation, pending: false } : mutation,
    )

    // Successful patches stay in the replay chain while a later mutation
    // still depends on them. Once the queue settles, Electric is the truth.
    if (!optimistic.some((mutation) => mutation.pending)) optimistic = []
  }

  const settleFailure = (id: number, cause: unknown): Error => {
    optimistic = optimistic.filter((mutation) => mutation.id !== id)
    if (!optimistic.some((mutation) => mutation.pending)) optimistic = []
    mutationError = toError(cause)
    return mutationError
  }

  const runNextWrite = () => {
    if (writing) return
    const queued = writeQueue.shift()
    if (!queued) return
    writing = true

    let result: Promise<unknown>
    try {
      result = queued.run()
    } catch (cause) {
      queued.reject(settleFailure(queued.id, cause))
      writing = false
      runNextWrite()
      return
    }

    void result.then(
      () => {
        settleSuccess(queued.id)
        queued.resolve()
        writing = false
        runNextWrite()
      },
      (cause: unknown) => {
        queued.reject(settleFailure(queued.id, cause))
        writing = false
        runNextWrite()
      },
    )
  }

  const apply = (patch: (rows: T[]) => T[], write: () => Promise<unknown>): Promise<void> => {
    const id = nextMutationId
    nextMutationId += 1
    optimistic = [...optimistic, { id, pending: true, patch }]
    mutationError = null

    return new Promise<void>((resolve, reject) => {
      writeQueue.push({ id, run: write, resolve, reject })
      runNextWrite()
    })
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
      optimistic = []
      mutationError = null
      store.retry()
    },
    insert(row) {
      return apply(
        (rows) => {
          let replaced = false
          const next = rows.map((existing) => {
            if (identify(existing) !== identify(row)) return existing
            replaced = true
            return row
          })
          return replaced ? next : [...next, row]
        },
        () => mutations.onInsert?.(row) ?? Promise.resolve(),
      )
    },
    update(id, changes) {
      return apply(
        (rows) => rows.map((row) => (identify(row) === id ? { ...row, ...changes } : row)),
        () => mutations.onUpdate?.(id, changes) ?? Promise.resolve(),
      )
    },
    remove(id) {
      return apply(
        (rows) => rows.filter((row) => identify(row) !== id),
        () => mutations.onRemove?.(id) ?? Promise.resolve(),
      )
    },
  }
}

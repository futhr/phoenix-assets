import { flushSync } from "svelte"
import { beforeEach, describe, expect, it, vi } from "vitest"

// A subscription only starts inside a reactive context, so every assertion here
// runs with an `$effect` observing the store — the same shape a component has.
const h = vi.hoisted(() => ({
  rows: [] as Array<{ id: string; name: string }>,
  error: false as false | Error,
  callbacks: [] as Array<() => void>,
}))

vi.mock("@electric-sql/client", () => ({
  ShapeStream: class {
    unsubscribeAll = vi.fn()
  },
  Shape: class {
    get currentRows() {
      return h.rows
    }
    get error() {
      return h.error
    }
    subscribe(callback: () => void) {
      h.callbacks.push(callback)
      callback()
      return () => {}
    }
  },
}))

const { createMutableShapeStore, createShapeStore } = await import(
  "../src/electric/shape-store.svelte"
)

type Row = { id: string; name: string }

/** Observes `read` through an effect and returns what it last saw. */
function observe<T>(read: () => T): { latest: () => T; stop: () => void } {
  let latest!: T
  const stop = $effect.root(() => {
    $effect(() => {
      latest = read()
    })
  })
  flushSync()
  return { latest: () => latest, stop }
}

beforeEach(() => {
  h.rows = []
  h.error = false
  h.callbacks.length = 0
})

describe("status and error", () => {
  it("reports ready once the shape has reported", () => {
    const store = createShapeStore<Row>("/shapes/rows")
    const { latest, stop } = observe(() => ({ status: store.status, error: store.error }))

    expect(latest()).toEqual({ status: "ready", error: null })
    stop()
  })

  // Without this, an empty result and a failed sync look identical.
  it("reports a failed sync rather than an empty one", () => {
    h.error = new Error("gone")

    const store = createShapeStore<Row>("/shapes/rows")
    const { latest, stop } = observe(() => ({ status: store.status, error: store.error }))

    expect(latest().status).toBe("error")
    expect(latest().error?.message).toBe("gone")
    stop()
  })
})

describe("optimistic mutations", () => {
  it("shows an insert before the server confirms it", async () => {
    let resolveWrite: () => void = () => {}
    const onInsert = vi.fn(() => new Promise<void>((resolve) => (resolveWrite = resolve)))

    const store = createMutableShapeStore<Row>("/shapes/rows", { onInsert })
    const { latest, stop } = observe(() => store.rows)

    const pending = store.insert({ id: "1", name: "new" })
    flushSync()

    expect(latest()).toEqual([{ id: "1", name: "new" }])
    expect(onInsert).toHaveBeenCalledOnce()

    resolveWrite()
    await pending
    stop()
  })

  it("puts the previous rows back when the write fails", async () => {
    h.rows = [{ id: "1", name: "old" }]
    const onUpdate = vi.fn().mockRejectedValue(new Error("conflict"))

    const store = createMutableShapeStore<Row>("/shapes/rows", { onUpdate })
    const { latest, stop } = observe(() => store.rows)

    await expect(store.update("1", { name: "new" })).rejects.toThrow("conflict")
    flushSync()

    expect(latest()).toEqual([{ id: "1", name: "old" }])
    expect(store.error?.message).toBe("conflict")
    stop()
  })

  it("drops the overlay once the write settles, so sync is the truth again", async () => {
    h.rows = [
      { id: "1", name: "a" },
      { id: "2", name: "b" },
    ]

    const store = createMutableShapeStore<Row>("/shapes/rows", { identify: (row) => row.name })
    const { latest, stop } = observe(() => store.rows)

    await store.remove("a")
    flushSync()

    expect(latest()).toEqual(h.rows)
    stop()
  })

  it("removes the matching row optimistically", async () => {
    h.rows = [
      { id: "1", name: "a" },
      { id: "2", name: "b" },
    ]

    let resolveWrite: () => void = () => {}
    const onRemove = vi.fn(() => new Promise<void>((resolve) => (resolveWrite = resolve)))

    const store = createMutableShapeStore<Row>("/shapes/rows", { onRemove })
    const { latest, stop } = observe(() => store.rows)

    const pending = store.remove("1")
    flushSync()

    expect(latest()).toEqual([{ id: "2", name: "b" }])

    resolveWrite()
    await pending
    stop()
  })

  it("clears a failed mutation on retry", async () => {
    const onInsert = vi.fn().mockRejectedValue(new Error("nope"))

    const store = createMutableShapeStore<Row>("/shapes/rows", { onInsert })
    const { stop } = observe(() => store.rows)

    await expect(store.insert({ id: "1", name: "x" })).rejects.toThrow()
    expect(store.error).not.toBeNull()

    store.retry()
    flushSync()

    expect(store.error).toBeNull()
    stop()
  })
})

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

interface Deferred {
  promise: Promise<void>
  resolve: () => void
  reject: (error: Error) => void
}

function deferred(): Deferred {
  let resolve: () => void = () => {}
  let reject: (error: Error) => void = () => {}
  const promise = new Promise<void>((accept, decline) => {
    resolve = accept
    reject = decline
  })
  return { promise, resolve, reject }
}

function syncRows(rows: Row[]): void {
  h.rows = rows
  for (const callback of h.callbacks) callback()
  flushSync()
}

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

  it("serializes writes while composing newer optimistic updates", async () => {
    h.rows = [
      { id: "1", name: "one" },
      { id: "2", name: "two" },
    ]
    const firstWrite = deferred()
    const secondWrite = deferred()
    const onUpdate = vi
      .fn()
      .mockImplementationOnce(() => firstWrite.promise)
      .mockImplementationOnce(() => secondWrite.promise)

    const store = createMutableShapeStore<Row>("/shapes/rows", { onUpdate })
    const { latest, stop } = observe(() => store.rows)
    const first = store.update("1", { name: "first" })
    const second = store.update("2", { name: "second" })
    flushSync()

    expect(latest()).toEqual([
      { id: "1", name: "first" },
      { id: "2", name: "second" },
    ])
    expect(onUpdate).toHaveBeenCalledTimes(1)

    firstWrite.resolve()
    await first
    flushSync()

    expect(onUpdate).toHaveBeenCalledTimes(2)
    expect(latest()).toEqual([
      { id: "1", name: "first" },
      { id: "2", name: "second" },
    ])

    syncRows([
      { id: "1", name: "first" },
      { id: "2", name: "two" },
    ])
    expect(latest()).toEqual([
      { id: "1", name: "first" },
      { id: "2", name: "second" },
    ])

    secondWrite.resolve()
    await second
    stop()
  })

  it("rolls back only the failed patch and continues later writes", async () => {
    h.rows = [{ id: "1", name: "old" }]
    const firstWrite = deferred()
    const secondWrite = deferred()
    const onUpdate = vi
      .fn()
      .mockImplementationOnce(() => firstWrite.promise)
      .mockImplementationOnce(() => secondWrite.promise)

    const store = createMutableShapeStore<Row>("/shapes/rows", { onUpdate })
    const { latest, stop } = observe(() => store.rows)
    const first = store.update("1", { name: "stale" })
    const rejected = expect(first).rejects.toThrow("conflict")
    const second = store.update("1", { name: "newest" })
    flushSync()
    expect(latest()).toEqual([{ id: "1", name: "newest" }])

    firstWrite.reject(new Error("conflict"))
    await rejected
    flushSync()

    expect(onUpdate).toHaveBeenCalledTimes(2)
    expect(latest()).toEqual([{ id: "1", name: "newest" }])
    expect(store.error?.message).toBe("conflict")

    syncRows([{ id: "1", name: "old" }])
    expect(latest()).toEqual([{ id: "1", name: "newest" }])

    secondWrite.resolve()
    await second
    stop()
  })

  it("keeps a synced first update when a newer same-row update fails", async () => {
    h.rows = [{ id: "1", name: "old" }]
    const firstWrite = deferred()
    const secondWrite = deferred()
    const onUpdate = vi
      .fn()
      .mockImplementationOnce(() => firstWrite.promise)
      .mockImplementationOnce(() => secondWrite.promise)

    const store = createMutableShapeStore<Row>("/shapes/rows", { onUpdate })
    const { latest, stop } = observe(() => store.rows)
    const first = store.update("1", { name: "accepted" })
    const second = store.update("1", { name: "rejected" })
    const rejected = expect(second).rejects.toThrow("rejected")
    flushSync()
    expect(latest()).toEqual([{ id: "1", name: "rejected" }])

    firstWrite.resolve()
    await first
    syncRows([{ id: "1", name: "accepted" }])
    expect(latest()).toEqual([{ id: "1", name: "rejected" }])

    secondWrite.reject(new Error("rejected"))
    await rejected
    flushSync()
    expect(latest()).toEqual([{ id: "1", name: "accepted" }])
    stop()
  })

  it("removes a failed insert without hiding a newer different-row update", async () => {
    h.rows = [{ id: "2", name: "old" }]
    const insertWrite = deferred()
    const updateWrite = deferred()
    const store = createMutableShapeStore<Row>("/shapes/rows", {
      onInsert: () => insertWrite.promise,
      onUpdate: () => updateWrite.promise,
    })
    const { latest, stop } = observe(() => store.rows)
    const inserted = store.insert({ id: "1", name: "new" })
    const rejected = expect(inserted).rejects.toThrow("duplicate")
    const updated = store.update("2", { name: "edited" })
    flushSync()
    expect(latest()).toEqual([
      { id: "2", name: "edited" },
      { id: "1", name: "new" },
    ])

    insertWrite.reject(new Error("duplicate"))
    await rejected
    flushSync()
    expect(latest()).toEqual([{ id: "2", name: "edited" }])

    syncRows([{ id: "2", name: "edited" }])
    updateWrite.resolve()
    await updated
    expect(latest()).toEqual([{ id: "2", name: "edited" }])
    stop()
  })

  it("restores a failed remove while preserving a newer insert", async () => {
    h.rows = [{ id: "1", name: "kept" }]
    const removeWrite = deferred()
    const insertWrite = deferred()
    const store = createMutableShapeStore<Row>("/shapes/rows", {
      onInsert: () => insertWrite.promise,
      onRemove: () => removeWrite.promise,
    })
    const { latest, stop } = observe(() => store.rows)
    const removed = store.remove("1")
    const rejected = expect(removed).rejects.toThrow("protected")
    const inserted = store.insert({ id: "2", name: "new" })
    flushSync()
    expect(latest()).toEqual([{ id: "2", name: "new" }])

    removeWrite.reject(new Error("protected"))
    await rejected
    flushSync()
    expect(latest()).toEqual([
      { id: "1", name: "kept" },
      { id: "2", name: "new" },
    ])

    syncRows([
      { id: "1", name: "kept" },
      { id: "2", name: "new" },
    ])
    insertWrite.resolve()
    await inserted
    expect(latest()).toEqual(h.rows)
    stop()
  })

  it("keeps insert, update, and remove patches ordered across sync arrival", async () => {
    const insertWrite = deferred()
    const updateWrite = deferred()
    const removeWrite = deferred()
    const store = createMutableShapeStore<Row>("/shapes/rows", {
      onInsert: () => insertWrite.promise,
      onUpdate: () => updateWrite.promise,
      onRemove: () => removeWrite.promise,
    })
    const { latest, stop } = observe(() => store.rows)

    const inserted = store.insert({ id: "1", name: "draft" })
    const updated = store.update("1", { name: "edited" })
    const removed = store.remove("1")
    flushSync()
    expect(latest()).toEqual([])

    insertWrite.resolve()
    await inserted
    flushSync()
    expect(latest()).toEqual([])

    syncRows([{ id: "1", name: "server draft" }])
    expect(latest()).toEqual([])

    updateWrite.resolve()
    await updated
    flushSync()
    expect(latest()).toEqual([])

    syncRows([{ id: "1", name: "edited" }])
    expect(latest()).toEqual([])

    removeWrite.resolve()
    await removed
    syncRows([])
    expect(latest()).toEqual([])
    stop()
  })
})

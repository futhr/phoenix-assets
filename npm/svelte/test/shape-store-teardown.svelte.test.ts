import { flushSync } from "svelte"
import { beforeEach, describe, expect, it, vi } from "vitest"

// Independent module mock (kept separate from shape-store.svelte.test.ts) so the
// stream stub can expose `unsubscribeAll` and capture the `signal` handed to the
// ShapeStream constructor -- the two things the teardown/leak fix must exercise.
const h = vi.hoisted(() => ({
  rows: [] as unknown[],
  callbacks: [] as Array<() => void>,
  unsubscribe: vi.fn(),
  unsubscribeAll: vi.fn(),
  opts: [] as Array<{ url: string; signal?: AbortSignal }>,
}))

vi.mock("@electric-sql/client", () => ({
  ShapeStream: vi.fn(function (opts: { url: string; signal?: AbortSignal }) {
    h.opts.push(opts)
    return { unsubscribeAll: h.unsubscribeAll }
  }),
  Shape: class {
    get currentRows() {
      return h.rows
    }
    subscribe(cb: () => void) {
      h.callbacks.push(cb)
      return h.unsubscribe
    }
  },
}))

import { ShapeStream } from "@electric-sql/client"
import { createShapeStore } from "../src/electric/shape-store"

beforeEach(() => {
  h.rows = []
  h.callbacks.length = 0
  h.opts.length = 0
  h.unsubscribe.mockClear()
  h.unsubscribeAll.mockClear()
  vi.mocked(ShapeStream).mockClear()
})

function observe(store: { rows: unknown[] }) {
  return $effect.root(() => {
    $effect(() => {
      void store.rows
    })
  })
}

describe("createShapeStore teardown (leak fix)", () => {
  it("aborts the stream's AbortController and unsubscribes the stream when the last reader stops", () => {
    const store = createShapeStore("/shapes/users/:id", { id: 1 })
    const stop = observe(store)
    flushSync()

    expect(ShapeStream).toHaveBeenCalledTimes(1)
    const signal = h.opts[0]?.signal
    // The store owns a per-subscription AbortController and threads its signal
    // into the stream so an in-flight fetch can be cancelled on teardown.
    expect(signal).toBeInstanceOf(AbortSignal)
    expect(signal?.aborted).toBe(false)

    stop()
    flushSync()

    // The leak fix: teardown must abort the controller AND tear the stream down,
    // otherwise the ShapeStream keeps its long-poll/socket open forever.
    expect(signal?.aborted).toBe(true)
    expect(h.unsubscribeAll).toHaveBeenCalledTimes(1)
    expect(h.unsubscribe).toHaveBeenCalledTimes(1)
  })

  it("creates a fresh, un-aborted controller when re-observed after teardown", () => {
    const store = createShapeStore("/shapes/things")

    const stop1 = observe(store)
    flushSync()
    const firstSignal = h.opts[0]?.signal
    stop1()
    flushSync()
    expect(firstSignal?.aborted).toBe(true)

    const stop2 = observe(store)
    flushSync()

    // A new subscription must not reuse the aborted controller from the first run.
    expect(ShapeStream).toHaveBeenCalledTimes(2)
    const secondSignal = h.opts[1]?.signal
    expect(secondSignal).not.toBe(firstSignal)
    expect(secondSignal?.aborted).toBe(false)

    stop2()
    flushSync()
    expect(secondSignal?.aborted).toBe(true)
    expect(h.unsubscribeAll).toHaveBeenCalledTimes(2)
  })
})

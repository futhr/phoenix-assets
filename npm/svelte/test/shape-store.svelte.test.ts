import { flushSync } from "svelte"
import { beforeEach, describe, expect, it, vi } from "vitest"

const h = vi.hoisted(() => ({
  rows: [] as unknown[],
  callbacks: [] as Array<() => void>,
  unsubscribe: vi.fn(),
}))

vi.mock("@electric-sql/client", () => ({
  ShapeStream: vi.fn(function () {
    return { unsubscribeAll() {} }
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
  h.unsubscribe.mockClear()
  vi.mocked(ShapeStream).mockClear()
})

describe("createShapeStore", () => {
  it("subscribes when observed and exposes reactive rows from the shape URL", () => {
    const store = createShapeStore<{ id: number }>("/shapes/users/:id", { id: 7 })
    const seen: Array<Array<{ id: number }>> = []

    const stop = $effect.root(() => {
      $effect(() => {
        seen.push(store.rows)
      })
    })
    flushSync()

    expect(ShapeStream).toHaveBeenCalledTimes(1)
    const opts = vi.mocked(ShapeStream).mock.calls[0][0] as { url: string }
    expect(opts.url).toContain("/shapes/users/7")
    expect(seen.at(-1)).toEqual([])

    h.rows = [{ id: 1 }]
    h.callbacks[0]()
    flushSync()
    expect(seen.at(-1)).toEqual([{ id: 1 }])

    stop()
    flushSync()
    expect(h.unsubscribe).toHaveBeenCalledTimes(1)
  })

  it("resolves a thunk path lazily and tears down when unobserved", () => {
    const store = createShapeStore(() => "/shapes/things")
    const seen: unknown[] = []

    const stop = $effect.root(() => {
      $effect(() => {
        seen.push(store.rows)
      })
    })
    flushSync()

    const opts = vi.mocked(ShapeStream).mock.calls[0][0] as { url: string }
    expect(opts.url).toContain("/shapes/things")

    stop()
    flushSync()
    expect(h.unsubscribe).toHaveBeenCalledTimes(1)
  })
})

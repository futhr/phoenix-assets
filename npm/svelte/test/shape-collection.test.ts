import { afterEach, expect, it, vi } from "vitest"
import { createShapeCollection } from "../src/electric/shape-collection"

afterEach(() => vi.unstubAllGlobals())

it("synchronizes an Electric snapshot and releases the stream on cleanup", async () => {
  let token = "first"
  const fetchFn = vi.fn<typeof fetch>().mockImplementation(async (_, init) => {
    if (fetchFn.mock.calls.length > 1) {
      return new Promise<Response>((_, reject) => {
        init?.signal?.addEventListener(
          "abort",
          () => reject(new DOMException("Aborted", "AbortError")),
          { once: true },
        )
      })
    }
    token = "second"
    return new Response(
      JSON.stringify([
        { key: "1", value: { id: 1, label: "First" }, headers: { operation: "insert" } },
        { headers: { control: "up-to-date" } },
      ]),
      {
        headers: {
          "content-type": "application/json",
          "electric-offset": "0_0",
          "electric-handle": "test-shape",
          "electric-schema": JSON.stringify({ id: { type: "int4" }, label: { type: "text" } }),
        },
      },
    )
  })
  vi.stubGlobal("fetch", fetchFn)
  const collection = createShapeCollection<{ id: number; label: string }>(
    "https://example.test/shapes/:id",
    { id: 7 },
    { readToken: () => token },
  )
  try {
    await collection.preload()
    expect(collection.get(1)).toMatchObject({ id: 1, label: "First" })
    expect(new URL(String(fetchFn.mock.calls[0]?.[0])).pathname).toBe("/shapes/7")
    expect(new Headers(fetchFn.mock.calls[0]?.[1]?.headers).get("authorization")).toBe(
      "Bearer first",
    )
    await vi.waitFor(() => expect(fetchFn).toHaveBeenCalledTimes(2))
    expect(new Headers(fetchFn.mock.calls[1]?.[1]?.headers).get("authorization")).toBe(
      "Bearer second",
    )
  } finally {
    await collection.cleanup()
    expect(fetchFn.mock.calls.at(-1)?.[1]?.signal?.aborted).toBe(true)
  }
})

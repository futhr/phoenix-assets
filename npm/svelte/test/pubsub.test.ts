import { describe, expect, it, vi } from "vitest"
import { matchEvent } from "../src/pubsub/topics"

type DeviceEvent =
  | { type: "device:updated"; payload: { id: string } }
  | { type: "device:deleted"; payload: { id: string } }

describe("matchEvent", () => {
  it("dispatches to the matching handler with a narrowed payload", () => {
    let seen = ""

    matchEvent<DeviceEvent>(
      { type: "device:updated", payload: { id: "1" } },
      { "device:updated": (event) => (seen = event.payload.id) },
    )

    expect(seen).toBe("1")
  })

  it("is a no-op when no handler matches", () => {
    expect(() =>
      matchEvent<DeviceEvent>({ type: "device:deleted", payload: { id: "x" } }, {}),
    ).not.toThrow()
  })
})

it("ignores inherited event handlers while accepting explicit own handlers", () => {
  expect(() => matchEvent({ type: "__proto__" }, {})).not.toThrow()
  const handler = vi.fn()
  matchEvent({ type: "constructor" }, Object.create({ constructor: handler }))
  expect(handler).not.toHaveBeenCalled()
  matchEvent({ type: "constructor" }, { constructor: handler })
  expect(handler).toHaveBeenCalledOnce()
})

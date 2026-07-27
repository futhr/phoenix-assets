import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import {
  debounce,
  once,
  preventDefault,
  self,
  stopPropagation,
  throttle,
} from "../src/events/modifiers"

const event = (overrides: Partial<Event> = {}): Event => ({ ...overrides }) as Event

beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
})

describe("debounce", () => {
  it("runs once after the quiet period, not per call", () => {
    const handler = vi.fn()
    const wrapped = debounce(handler, 300)

    wrapped(event())
    wrapped(event())
    wrapped(event())
    expect(handler).not.toHaveBeenCalled()

    vi.advanceTimersByTime(300)
    expect(handler).toHaveBeenCalledTimes(1)
  })

  it("restarts the timer on every call", () => {
    const handler = vi.fn()
    const wrapped = debounce(handler, 300)

    wrapped(event())
    vi.advanceTimersByTime(200)
    wrapped(event())
    vi.advanceTimersByTime(200)
    expect(handler).not.toHaveBeenCalled()

    vi.advanceTimersByTime(100)
    expect(handler).toHaveBeenCalledTimes(1)
  })

  it("drops pending work when cancelled", () => {
    const handler = vi.fn()
    const wrapped = debounce(handler, 300)

    wrapped(event())
    wrapped.cancel()
    vi.advanceTimersByTime(1000)

    expect(handler).not.toHaveBeenCalled()
  })

  it("is safe to cancel when nothing is pending", () => {
    expect(() => debounce(vi.fn(), 300).cancel()).not.toThrow()
  })
})

describe("throttle", () => {
  it("runs immediately then drops calls inside the window", () => {
    const handler = vi.fn()
    const wrapped = throttle(handler, 100)

    wrapped(event())
    wrapped(event())
    wrapped(event())

    expect(handler).toHaveBeenCalledTimes(1)
  })

  it("runs again once the window has passed", () => {
    const handler = vi.fn()
    const wrapped = throttle(handler, 100)

    wrapped(event())
    vi.advanceTimersByTime(100)
    wrapped(event())

    expect(handler).toHaveBeenCalledTimes(2)
  })

  it("does not queue a backlog of dropped calls", () => {
    const handler = vi.fn()
    const wrapped = throttle(handler, 100)

    for (let i = 0; i < 20; i++) wrapped(event())
    vi.advanceTimersByTime(1000)

    expect(handler).toHaveBeenCalledTimes(1)
  })

  it("reopens the window when cancelled", () => {
    const handler = vi.fn()
    const wrapped = throttle(handler, 100)

    wrapped(event())
    wrapped.cancel()
    wrapped(event())

    expect(handler).toHaveBeenCalledTimes(2)
  })
})

describe("once", () => {
  it("runs the handler for the first event only", () => {
    const handler = vi.fn()
    const wrapped = once(handler)

    wrapped(event())
    wrapped(event())

    expect(handler).toHaveBeenCalledTimes(1)
  })
})

describe("stopPropagation and preventDefault", () => {
  it("stops the event before running the handler", () => {
    const stop = vi.fn()
    const handler = vi.fn()

    stopPropagation(handler)(event({ stopPropagation: stop }))

    expect(stop).toHaveBeenCalledTimes(1)
    expect(handler).toHaveBeenCalledTimes(1)
  })

  it("prevents the default before running the handler", () => {
    const prevent = vi.fn()
    const handler = vi.fn()

    preventDefault(handler)(event({ preventDefault: prevent }))

    expect(prevent).toHaveBeenCalledTimes(1)
    expect(handler).toHaveBeenCalledTimes(1)
  })

  it("stops the event even on a call the inner modifier drops", () => {
    const stop = vi.fn()
    const handler = vi.fn()
    const wrapped = stopPropagation(debounce(handler, 300))

    wrapped(event({ stopPropagation: stop }))
    wrapped(event({ stopPropagation: stop }))

    expect(stop).toHaveBeenCalledTimes(2)
    vi.advanceTimersByTime(300)
    expect(handler).toHaveBeenCalledTimes(1)
  })
})

describe("self", () => {
  it("runs only when the event targets the bound element", () => {
    const handler = vi.fn()
    const element = {} as EventTarget

    self(handler)(event({ target: element, currentTarget: element }))
    expect(handler).toHaveBeenCalledTimes(1)

    self(handler)(event({ target: {} as EventTarget, currentTarget: element }))
    expect(handler).toHaveBeenCalledTimes(1)
  })
})

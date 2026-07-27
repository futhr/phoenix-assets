import { afterEach, describe, expect, it, vi } from "vitest"
import { runCommand } from "../src/commands/run"

const ERRORS = ["edit_rejected", "not_found"] as const

function respond(
  status: number,
  body: unknown,
  init: { json?: () => Promise<unknown> } = {},
): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: init.json ?? (async () => body),
  } as unknown as Response
}

afterEach(() => {
  vi.restoreAllMocks()
  localStorage.clear()
})

describe("runCommand", () => {
  it("returns the parsed payload on success", async () => {
    const fetchFn = vi.fn().mockResolvedValue(respond(200, { id: "page-1" }))

    expect(
      await runCommand({ path: "/api/pages", method: "POST", fetch: fetchFn }, ERRORS),
    ).toEqual({ ok: true, data: { id: "page-1" } })
  })

  it("substitutes path params and serialises the body", async () => {
    const fetchFn = vi.fn().mockResolvedValue(respond(200, {}))

    await runCommand(
      {
        path: "/api/pages/:id/layout",
        method: "PUT",
        params: { id: "a b" },
        body: { layout_ir: { root: {} } },
        fetch: fetchFn,
      },
      ERRORS,
    )

    const [url, init] = fetchFn.mock.calls[0]
    expect(url).toBe("/api/pages/a%20b/layout")
    expect(init.method).toBe("PUT")
    expect(init.body).toBe(JSON.stringify({ layout_ir: { root: {} } }))
    expect(init.headers["Content-Type"]).toBe("application/json")
  })

  it("omits the body entirely when none is given", async () => {
    const fetchFn = vi.fn().mockResolvedValue(respond(200, {}))

    await runCommand({ path: "/api/ping", method: "POST", fetch: fetchFn }, ERRORS)

    expect(fetchFn.mock.calls[0][1]).not.toHaveProperty("body")
  })

  it("passes a declared error code through with its own name", async () => {
    const fetchFn = vi.fn().mockResolvedValue(respond(422, { error: "edit_rejected" }))

    expect(
      await runCommand({ path: "/api/pages", method: "POST", fetch: fetchFn }, ERRORS),
    ).toEqual({ ok: false, error: "edit_rejected", status: 422 })
  })

  it("degrades an undeclared code to unknown_error rather than leaking it", async () => {
    const fetchFn = vi.fn().mockResolvedValue(respond(422, { error: "brand_new_code" }))

    expect(
      await runCommand({ path: "/api/pages", method: "POST", fetch: fetchFn }, ERRORS),
    ).toEqual({ ok: false, error: "unknown_error", status: 422 })
  })

  it("treats a bodiless or unparseable failure as unknown_error", async () => {
    const unparseable = respond(500, null, {
      json: async () => {
        throw new Error("not json")
      },
    })
    const fetchFn = vi.fn().mockResolvedValue(unparseable)

    expect(
      await runCommand({ path: "/api/pages", method: "POST", fetch: fetchFn }, ERRORS),
    ).toEqual({ ok: false, error: "unknown_error", status: 500 })
  })

  it("never rejects when the request itself fails", async () => {
    const fetchFn = vi.fn().mockRejectedValue(new Error("offline"))

    expect(
      await runCommand({ path: "/api/pages", method: "POST", fetch: fetchFn }, ERRORS),
    ).toEqual({ ok: false, error: "unknown_error", status: 0 })
  })

  it("returns null data for a 204 without reading the body", async () => {
    const json = vi.fn()
    const fetchFn = vi.fn().mockResolvedValue(respond(204, null, { json }))

    expect(
      await runCommand({ path: "/api/pages/1", method: "DELETE", fetch: fetchFn }, ERRORS),
    ).toEqual({ ok: true, data: null })
    expect(json).not.toHaveBeenCalled()
  })

  it("sends the auth header when a token is present", async () => {
    localStorage.setItem("auth_token", "t-1")
    const fetchFn = vi.fn().mockResolvedValue(respond(200, {}))

    await runCommand({ path: "/api/pages", method: "POST", fetch: fetchFn }, ERRORS)

    expect(fetchFn.mock.calls[0][1].headers.Authorization).toBe("Bearer t-1")
  })

  it("lets caller headers win over the defaults", async () => {
    const fetchFn = vi.fn().mockResolvedValue(respond(200, {}))

    await runCommand(
      {
        path: "/api/pages",
        method: "POST",
        fetch: fetchFn,
        headers: { "Content-Type": "application/vnd.api+json" },
      },
      ERRORS,
    )

    expect(fetchFn.mock.calls[0][1].headers["Content-Type"]).toBe("application/vnd.api+json")
  })

  it("forwards an abort signal", async () => {
    const fetchFn = vi.fn().mockResolvedValue(respond(200, {}))
    const controller = new AbortController()

    await runCommand(
      { path: "/api/pages", method: "POST", fetch: fetchFn, signal: controller.signal },
      ERRORS,
    )

    expect(fetchFn.mock.calls[0][1].signal).toBe(controller.signal)
  })

  it("treats every failure as unknown when no codes are declared", async () => {
    const fetchFn = vi.fn().mockResolvedValue(respond(403, { error: "forbidden" }))

    expect(await runCommand({ path: "/api/pages", method: "POST", fetch: fetchFn })).toEqual({
      ok: false,
      error: "unknown_error",
      status: 403,
    })
  })
})

import { afterEach, expect, it, vi } from "vitest"
import { configureShapeAuth, createShapeFetch, resetShapeAuth } from "../src/electric/url"

afterEach(() => {
  resetShapeAuth()
  localStorage.clear()
  vi.unstubAllGlobals()
})

it("refreshes credentials and dynamic headers on every request, including logout", async () => {
  let token: string | undefined = "first"
  let tenant = "one"
  configureShapeAuth({ readToken: () => token, headers: () => ({ "X-Tenant": tenant }) })
  const fetchFn = vi.fn<typeof fetch>().mockResolvedValue(new Response("{}"))
  const request = createShapeFetch({}, fetchFn)
  const signal = new AbortController().signal
  await request("/shape", { signal, headers: { "electric-handle": "handle" } })
  token = "second"
  tenant = "two"
  await request("/shape")
  token = undefined
  await request("/shape")
  const first = new Headers(fetchFn.mock.calls[0]?.[1]?.headers)
  const second = new Headers(fetchFn.mock.calls[1]?.[1]?.headers)
  const third = new Headers(fetchFn.mock.calls[2]?.[1]?.headers)
  expect(first.get("authorization")).toBe("Bearer first")
  expect(first.get("electric-handle")).toBe("handle")
  expect(fetchFn.mock.calls[0]?.[1]?.signal).toBe(signal)
  expect(second.get("authorization")).toBe("Bearer second")
  expect(second.get("x-tenant")).toBe("two")
  expect(third.has("authorization")).toBe(false)
})

it("retains Request headers and uses the current global fetch by default", async () => {
  const fetchFn = vi.fn<typeof fetch>().mockResolvedValue(new Response("{}"))
  const request = createShapeFetch({ readToken: () => "token" })
  vi.stubGlobal("fetch", fetchFn)
  await request(
    new Request("https://example.test/shape", { headers: { accept: "application/json" } }),
  )
  expect(new Headers(fetchFn.mock.calls[0]?.[1]?.headers).get("accept")).toBe("application/json")
})

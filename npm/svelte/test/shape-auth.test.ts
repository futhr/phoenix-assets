import { afterEach, describe, expect, it } from "vitest"
import { authHeaders, configureShapeAuth, getAuthToken, resetShapeAuth } from "../src/index.js"

afterEach(() => {
  resetShapeAuth()
  localStorage.clear()
})

describe("token sources", () => {
  it("prefers an explicit reader over storage", () => {
    localStorage.setItem("auth_token", "from-storage")

    expect(getAuthToken({ readToken: () => "from-reader" })).toBe("from-reader")
  })

  // A reader that has nothing yet (pre-hydration, say) must not shadow storage.
  it("falls through to storage when the reader returns nothing", () => {
    localStorage.setItem("auth_token", "from-storage")

    expect(getAuthToken({ readToken: () => undefined })).toBe("from-storage")
  })
})

describe("authHeaders", () => {
  it("is undefined when there is neither a token nor extra headers", () => {
    expect(authHeaders()).toBeUndefined()
  })

  it("carries the bearer token", () => {
    localStorage.setItem("auth_token", "abc")

    expect(authHeaders()).toEqual({ Authorization: "Bearer abc" })
  })

  // A bearer token is not the only thing a Phoenix app sends; without this seam
  // an app had to rebuild the whole header path to add a CSRF token.
  it("merges contributed headers alongside the token", () => {
    localStorage.setItem("auth_token", "abc")

    expect(authHeaders({ headers: () => ({ "X-CSRF-Token": "csrf" }) })).toEqual({
      Authorization: "Bearer abc",
      "X-CSRF-Token": "csrf",
    })
  })

  it("contributes headers even with no token at all", () => {
    expect(authHeaders({ headers: () => ({ "X-Tenant": "acme" }) })).toEqual({ "X-Tenant": "acme" })
  })

  it("re-reads the contributor per call, so a rotating value stays current", () => {
    let tick = 0
    configureShapeAuth({ headers: () => ({ "X-Nonce": String(++tick) }) })

    expect(authHeaders()).toEqual({ "X-Nonce": "1" })
    expect(authHeaders()).toEqual({ "X-Nonce": "2" })
  })

  it("lets an explicit config override the process-wide default", () => {
    configureShapeAuth({ localStorageKey: "default_key" })
    localStorage.setItem("default_key", "default-token")
    localStorage.setItem("other_key", "other-token")

    expect(authHeaders()).toEqual({ Authorization: "Bearer default-token" })
    expect(authHeaders({ localStorageKey: "other_key" })).toEqual({
      Authorization: "Bearer other-token",
    })
  })
})

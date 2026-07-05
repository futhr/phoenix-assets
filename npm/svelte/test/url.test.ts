import { afterEach, describe, expect, it, vi } from "vitest"
import { configureShapeAuth, createShapeUrl, getAuthToken } from "../src/electric/url"

describe("createShapeUrl", () => {
  it("substitutes and URL-encodes path params", () => {
    expect(createShapeUrl("/shapes/users/:id/posts", { id: "a b" })).toBe(
      "/shapes/users/a%20b/posts",
    )
  })

  it("appends non-path params as a query string", () => {
    expect(createShapeUrl("/shapes/posts", { limit: 10 })).toBe("/shapes/posts?limit=10")
  })

  it("leaves a plain path unchanged", () => {
    expect(createShapeUrl("/shapes/posts")).toBe("/shapes/posts")
  })

  it("substitutes every path param and appends leftovers as query", () => {
    expect(createShapeUrl("/orgs/:org/users/:id", { org: "acme", id: 7, limit: 5 })).toBe(
      "/orgs/acme/users/7?limit=5",
    )
  })

  it("throws a clear error naming the missing param and the path", () => {
    expect(() => createShapeUrl("/shapes/users/:id/posts", {})).toThrowError(
      'createShapeUrl: missing path param ":id" for "/shapes/users/:id/posts"',
    )
  })

  it("throws when only some of several path params are provided", () => {
    expect(() => createShapeUrl("/orgs/:org/users/:id", { org: "acme" })).toThrowError(
      /missing path param ":id"/,
    )
  })
})

describe("getAuthToken", () => {
  afterEach(() => vi.unstubAllGlobals())

  it("reads the token from localStorage", () => {
    vi.stubGlobal("localStorage", {
      getItem: (key: string) => (key === "auth_token" ? "tok" : null),
    })
    expect(getAuthToken()).toBe("tok")
  })

  it("returns undefined when no storage is available", () => {
    vi.stubGlobal("localStorage", undefined)
    expect(getAuthToken()).toBeUndefined()
  })

  it("falls back to a cookie, matching the cookie name literally", () => {
    vi.stubGlobal("localStorage", { getItem: () => null })
    vi.stubGlobal("document", { cookie: "myXtoken=wrong; my.token=right" })
    expect(getAuthToken({ cookieName: "my.token" })).toBe("right")
  })
})

describe("configureShapeAuth", () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    configureShapeAuth({ localStorageKey: "auth_token" })
  })

  it("makes getAuthToken read from the app-configured localStorage key", () => {
    configureShapeAuth({ localStorageKey: "refpath_cloud_token" })
    vi.stubGlobal("localStorage", {
      getItem: (key: string) => (key === "refpath_cloud_token" ? "tok2" : null),
    })
    expect(getAuthToken()).toBe("tok2")
  })
})

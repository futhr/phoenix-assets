import { afterEach, describe, expect, it, vi } from "vitest"
import { createShapeUrl, getAuthToken } from "../src/electric/url"

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
})

import { describe, expect, it } from "vitest"
import { resolveLocale } from "../src/localize/runtime"

describe("resolveLocale", () => {
  const supported = ["en", "sv"] as const

  it("returns an exact match", () => {
    expect(resolveLocale("sv", supported, "en")).toBe("sv")
  })

  it("falls back to the base language", () => {
    expect(resolveLocale("sv-SE", supported, "en")).toBe("sv")
  })

  it("falls back to the default for unsupported locales", () => {
    expect(resolveLocale("de", supported, "en")).toBe("en")
  })

  it("returns the default for null/undefined", () => {
    expect(resolveLocale(null, supported, "en")).toBe("en")
    expect(resolveLocale(undefined, supported, "en")).toBe("en")
  })
})

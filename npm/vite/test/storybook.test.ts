import { describe, expect, it } from "vitest"
import { createPhoenixViteConfig } from "../src/storybook"

describe("createPhoenixViteConfig", () => {
  it("returns a config fragment carrying the phoenix-assets plugins", () => {
    const plugins = createPhoenixViteConfig().plugins as Array<{ name?: string }>

    expect(Array.isArray(plugins)).toBe(true)
    expect(plugins.some((p) => p?.name?.startsWith("phoenix-assets"))).toBe(true)
  })

  it("accepts an explicit mode and extra options", () => {
    expect(createPhoenixViteConfig("app", { generatedDir: "gen" }).plugins).toBeDefined()
  })
})

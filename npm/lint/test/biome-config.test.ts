import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, expect, it } from "vitest"

const packageDirectory = join(dirname(fileURLToPath(import.meta.url)), "..")

describe("shared Biome config", () => {
  it("parses Tailwind directives in host stylesheets", () => {
    const config = JSON.parse(readFileSync(join(packageDirectory, "biome.base.json"), "utf-8"))

    expect(config.css.parser.tailwindDirectives).toBe(true)
  })
})

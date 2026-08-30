import { spawnSync } from "node:child_process"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, expect, it } from "vitest"

const packageDirectory = join(dirname(fileURLToPath(import.meta.url)), "..")
const fixtureDirectory = join(packageDirectory, "test", "fixtures", "app")
const entry = join(packageDirectory, "lint-svelte.ts")
const nodeFlags = ["--experimental-strip-types", "--no-warnings"]

const lint = (...paths: string[]) => {
  const result = spawnSync(process.execPath, [...nodeFlags, entry, ...paths], {
    cwd: fixtureDirectory,
    encoding: "utf-8",
  })

  return { status: result.status, output: `${result.stdout}${result.stderr}` }
}

describe("lint-svelte CLI", () => {
  it("accepts a component with one script block", () => {
    const { status, output } = lint("src/one-script.svelte")

    expect(status).toBe(0)
    expect(output).toContain("at most one script block")
  })

  it("ignores script-like text in Svelte comments", () => {
    const { status, output } = lint("src/script-comment.svelte")

    expect(status).toBe(0)
    expect(output).toContain("at most one script block")
  })

  it("rejects a component with module and instance script blocks", () => {
    const { status, output } = lint("src/two-scripts.svelte")

    expect(status).toBe(1)
    expect(output).toContain("src/two-scripts.svelte:5")
    expect(output).toContain("found 2 script blocks")
  })
})

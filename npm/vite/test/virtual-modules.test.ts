import { describe, expect, it } from "vitest"
import { virtualModulesPlugin } from "../src/virtual-modules"

type Hook = (...args: unknown[]) => unknown

function hook(value: unknown): Hook {
  return (typeof value === "function" ? value : (value as { handler: Hook }).handler) as Hook
}

function setup() {
  const plugin = virtualModulesPlugin({ generatedDir: "src/generated" })
  hook(plugin.configResolved).call({}, { root: "/tmp/app", command: "serve" })
  return plugin
}

describe("virtual modules", () => {
  it("resolves $phoenix/* ids to the internal namespace", () => {
    const resolveId = hook(setup().resolveId)

    expect(resolveId.call({}, "$phoenix/routes")).toBe("\0phoenix-assets:routes")
    expect(resolveId.call({}, "$phoenix/types")).toBe("\0phoenix-assets:types")
    expect(resolveId.call({}, "$phoenix/localize")).toBe("\0phoenix-assets:localize")
    expect(resolveId.call({}, "$phoenix/toString")).toBeNull()
    expect(resolveId.call({}, "react")).toBeNull()
  })

  it("returns a typed stub and warns when the generated file is missing", () => {
    const load = hook(setup().load)
    const warnings: string[] = []
    const ctx = { addWatchFile: () => undefined, warn: (message: string) => warnings.push(message) }

    const output = load.call(ctx, "\0phoenix-assets:routes") as string

    expect(output).toContain("export const routes")
    expect(warnings).toHaveLength(1)
  })

  it("ignores ids outside the resolved namespace", () => {
    expect(hook(setup().load).call({}, "some-other-module")).toBeNull()
  })
})

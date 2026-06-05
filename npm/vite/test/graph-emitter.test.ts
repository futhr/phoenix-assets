import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { afterEach, describe, expect, it } from "vitest"
import { graphEmitterPlugin } from "../src/graph-emitter"

type Hook = (...args: unknown[]) => unknown
function hook(value: unknown): Hook {
  return (typeof value === "function" ? value : (value as { handler: Hook }).handler) as Hook
}

const dirs: string[] = []
function tmp(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pa-graph-"))
  dirs.push(dir)
  return dir
}
afterEach(() => {
  for (const dir of dirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true })
})

const bundle = {
  "assets/app.123.js": {
    type: "chunk",
    isEntry: true,
    name: "app",
    imports: ["assets/vendor.456.js"],
  },
  "assets/vendor.456.js": { type: "chunk", isEntry: false, name: "vendor", imports: [] },
  "assets/app.789.css": { type: "asset" },
}

describe("graphEmitterPlugin", () => {
  it("writes graph.json with entry chunks when emitGraph is on", () => {
    const root = tmp()
    const plugin = graphEmitterPlugin({ emitGraph: true, graphOut: "graph.json" })

    hook(plugin.configResolved).call({}, { root, command: "build" })
    hook(plugin.writeBundle).call({}, {}, bundle)

    const graph = JSON.parse(fs.readFileSync(path.join(root, "graph.json"), "utf8"))
    expect(graph.version).toBe(1)
    expect(graph.generatedBy).toBe("@phoenix-assets/vite")
    expect(graph.entries.app).toEqual({
      file: "/assets/app.123.js",
      imports: ["/assets/vendor.456.js"],
    })
    expect(graph.entries.vendor).toBeUndefined()
  })

  it("is a no-op when emitGraph is off", () => {
    const root = tmp()
    const plugin = graphEmitterPlugin({ graphOut: "graph.json" })

    hook(plugin.configResolved).call({}, { root, command: "build" })
    hook(plugin.writeBundle).call({}, {}, bundle)

    expect(fs.existsSync(path.join(root, "graph.json"))).toBe(false)
  })
})

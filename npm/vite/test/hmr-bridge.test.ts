import path from "node:path"
import { describe, expect, it } from "vitest"
import { devClientPlugin } from "../src/dev-client/hmr-bridge"

type Hook = (...args: unknown[]) => unknown
function hook(value: unknown): Hook {
  return (typeof value === "function" ? value : (value as { handler: Hook }).handler) as Hook
}

function fakeServer() {
  const invalidated: unknown[] = []
  const sent: unknown[] = []
  const handlers: Record<string, (file: string) => void> = {}
  const fileMod = { id: "file-module" }
  const virtualMod = { id: "virtual-module" }

  return {
    moduleGraph: {
      getModulesByFile: (f: string) => (f.includes("generated") ? new Set([fileMod]) : undefined),
      getModuleById: (id: string) => (id.startsWith("\0phoenix-assets:") ? virtualMod : undefined),
      invalidateModule: (m: unknown) => invalidated.push(m),
    },
    ws: { send: (msg: unknown) => sent.push(msg) },
    watcher: {
      on: (event: string, cb: (file: string) => void) => {
        handlers[event] = cb
      },
    },
    invalidated,
    sent,
    handlers,
  }
}

function serve(root: string) {
  const plugin = devClientPlugin({ generatedDir: "src/generated" })
  hook(plugin.configResolved).call({}, { root, command: "serve" })
  const server = fakeServer()
  hook(plugin.configureServer).call({}, server)
  return server
}

describe("devClientPlugin", () => {
  it("registers change + add watchers", () => {
    const server = serve("/app")
    expect(typeof server.handlers.change).toBe("function")
    expect(typeof server.handlers.add).toBe("function")
  })

  it("invalidates file + virtual modules and reloads on a generated change", () => {
    const server = serve("/app")
    server.handlers.change(path.resolve("/app", "src/generated", "routes.ts"))

    expect(server.sent).toContainEqual({ type: "full-reload" })
    expect(server.invalidated.length).toBeGreaterThanOrEqual(2)
  })

  it("ignores changes outside the generated directory", () => {
    const server = serve("/app")
    server.handlers.change("/app/src/components/Button.svelte")

    expect(server.sent).toHaveLength(0)
    expect(server.invalidated).toHaveLength(0)
  })
})

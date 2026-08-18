import path from "node:path"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { devClientPlugin } from "../src/dev-client/hmr-bridge"

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())

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
  it("registers change + add + unlink watchers", () => {
    const server = serve("/app")
    expect(typeof server.handlers.change).toBe("function")
    expect(typeof server.handlers.add).toBe("function")
    expect(typeof server.handlers.unlink).toBe("function")
  })

  it("invalidates file + virtual modules and reloads on a debounced generated change", () => {
    const server = serve("/app")
    server.handlers.change(path.resolve("/app", "src/generated", "routes.ts"))
    vi.runAllTimers()

    expect(server.sent).toContainEqual({ type: "full-reload" })
    expect(server.invalidated.length).toBeGreaterThanOrEqual(2)
  })

  it("coalesces a burst of changes into a single reload", () => {
    const server = serve("/app")
    server.handlers.change(path.resolve("/app", "src/generated", "routes.ts"))
    server.handlers.change(path.resolve("/app", "src/generated", "env.ts"))
    vi.runAllTimers()

    expect(server.sent).toHaveLength(1)
  })

  it("ignores changes outside the generated directory", () => {
    const server = serve("/app")
    server.handlers.change("/app/src/components/button.svelte")
    vi.runAllTimers()

    expect(server.sent).toHaveLength(0)
    expect(server.invalidated).toHaveLength(0)
  })

  // Records which virtual-module ids were looked up + invalidated so a single
  // changed file can be shown to touch exactly one `$phoenix/*` virtual module.
  function targetedServe(root: string) {
    const plugin = devClientPlugin({ generatedDir: "src/generated" })
    hook(plugin.configResolved).call({}, { root, command: "serve" })

    const requestedIds: string[] = []
    const invalidatedIds: string[] = []
    const handlers: Record<string, (file: string) => void> = {}
    const server = {
      moduleGraph: {
        getModulesByFile: (f: string) => new Set([{ id: `disk:${path.basename(f)}` }]),
        getModuleById: (id: string) => {
          requestedIds.push(id)
          return { id }
        },
        invalidateModule: (m: { id: string }) => invalidatedIds.push(m.id),
      },
      ws: { send: () => {} },
      watcher: {
        on: (event: string, cb: (file: string) => void) => {
          handlers[event] = cb
        },
      },
    }
    hook(plugin.configureServer).call({}, server)
    return { handlers, requestedIds, invalidatedIds }
  }

  it("maps a changed generated file to only its own virtual module", () => {
    const s = targetedServe("/app")
    s.handlers.change(path.resolve("/app", "src/generated", "routes.ts"))
    vi.runAllTimers()

    // routes.ts backs `$phoenix/routes` -> the resolved id `\0phoenix-assets:routes`.
    expect(s.requestedIds).toEqual(["\0phoenix-assets:routes"])
    // No unrelated virtual module (env, types, ...) is invalidated.
    expect(s.invalidatedIds).not.toContain("\0phoenix-assets:env")
    // The virtual module plus the on-disk module for that one file are invalidated.
    expect(s.invalidatedIds).toEqual(["\0phoenix-assets:routes", "disk:routes.ts"])
  })

  it("routes a different generated file to its own virtual module", () => {
    const s = targetedServe("/app")
    s.handlers.change(path.resolve("/app", "src/generated", "env.ts"))
    vi.runAllTimers()

    expect(s.requestedIds).toEqual(["\0phoenix-assets:env"])
    expect(s.invalidatedIds).toEqual(["\0phoenix-assets:env", "disk:env.ts"])
  })

  it("does not look up any virtual module for an unmapped file in the generated dir", () => {
    const s = targetedServe("/app")
    // A file inside the watched dir that is not one of the GENERATED entries.
    s.handlers.change(path.resolve("/app", "src/generated", "stray.ts"))
    vi.runAllTimers()

    expect(s.requestedIds).toEqual([])
    // Only the on-disk module is invalidated; no virtual module is guessed.
    expect(s.invalidatedIds).toEqual(["disk:stray.ts"])
  })
})

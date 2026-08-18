import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, expect, it } from "vitest"

// `lint-tailwind.ts` has no exported units (it runs `main()` on import), so it is
// exercised as a black box: run the CLI against a fixture app and read its report.
const pkgDir = join(dirname(fileURLToPath(import.meta.url)), "..")
const appDir = join(pkgDir, "test", "fixtures", "app")

// Prefer the built binary when present (runs on any supported Node); otherwise
// run the TypeScript source via Node's type stripping (Node >= 22.6).
const distEntry = join(pkgDir, "dist", "lint-tailwind.js")
const useDist = existsSync(distEntry)
const entry = useDist ? distEntry : join(pkgDir, "lint-tailwind.ts")
const nodeFlags = useDist ? [] : ["--experimental-strip-types", "--no-warnings"]

function lint(relFile: string) {
  const res = spawnSync(process.execPath, [...nodeFlags, entry, relFile], {
    cwd: appDir,
    encoding: "utf-8",
  })
  // Everything the linter prints -- the violation report and the summary --
  // is worth matching against, so fold both streams together.
  return { status: res.status, out: `${res.stdout}${res.stderr}` }
}

describe("lint-tailwind CLI", () => {
  it("flags a reducible arbitrary value inside an expression class attribute", () => {
    // <div class={"z-[10] w-[180px]"}> -- the string literal is extracted and checked.
    const { status, out } = lint("src/expr.svelte")

    expect(status).toBe(1)
    expect(out).toContain('"z-[10]" can be written as "z-10"')
  })

  it("does not falsely flag a px arbitrary under a px-configured --spacing scale", () => {
    // With `--spacing: 4px`, a named step emits `calc(var(--spacing) * N)` while
    // `w-[180px]` emits a literal `180px`; the CSS-equality guard means the linter
    // suggests nothing rather than a wrong `w-45`. Regression for the px map fix.
    const { out } = lint("src/expr.svelte")

    expect(out).not.toContain("w-[180px]")
    expect(out).toContain("Found 1 unnecessary")
  })

  it("reports a utility call inside a class attribute exactly once", () => {
    // <div class={cn("order-[5]")}> must not be double-counted by the generic
    // CallExpression pass -- the `visitedCalls` dedup fix.
    const { status, out } = lint("src/utility.svelte")

    expect(status).toBe(1)
    expect(out).toContain("Found 1 unnecessary")
    const hits = out.match(/"order-\[5\]" can be written as "order-5"/g) ?? []
    expect(hits).toHaveLength(1)
  })
})

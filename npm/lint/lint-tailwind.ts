/// <reference types="node" />
/**
 * Tailwind CSS arbitrary value linter for Svelte + TypeScript files.
 *
 * Uses Tailwind v4's design system API to detect arbitrary pixel values
 * that have standard utility equivalents (e.g. `w-[180px]` → `w-45`).
 *
 * Two strategies:
 *   A) Pixel values: compute units from --spacing, verify via candidatesToCss
 *   B) CSS-value comparison: match non-px arbitrary forms against named CSS output
 *
 * Usage: node --experimental-strip-types lint-tailwind.ts [paths...]
 *        Defaults to src/**\/*.svelte + src/**\/*.variants.ts
 */

import { readdirSync, readFileSync } from "node:fs"
import { createRequire } from "node:module"
import { dirname, join, relative, resolve } from "node:path"

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Violation {
  file: string
  line: number
  col: number
  original: string
  replacement: string
}

interface ClassRegion {
  text: string
  line: number
  col: number
}

interface DesignSystem {
  candidatesToCss(classes: string[]): (string | null)[]
  getClassList(): [string, ...unknown[]][]
  resolveThemeValue(path: string): string | undefined
}

// ---------------------------------------------------------------------------
// 1. Design System Loader
// ---------------------------------------------------------------------------

const require = createRequire(import.meta.url)

interface TailwindModule {
  __unstable__loadDesignSystem(
    css: string,
    opts: {
      base: string
      loadStylesheet(
        id: string,
        base: string,
      ): Promise<{ path: string; base: string; content: string }>
    },
  ): DesignSystem
}

// This linter relies on Tailwind v4's UNDOCUMENTED `__unstable__loadDesignSystem`.
// Guard the dependency so an upstream change fails with an actionable message
// instead of a cryptic crash inside a host app's lint run.
const importTailwind = async (): Promise<TailwindModule> => {
  let mod: Partial<TailwindModule>

  try {
    // `tailwindcss` does not type its `__unstable__loadDesignSystem` internal,
    // so assert through `unknown` onto our hand-rolled shim (guarded below).
    mod = (await import("tailwindcss")) as unknown as Partial<TailwindModule>
  } catch {
    throw new Error(
      "lint-tailwind: cannot import `tailwindcss` — install Tailwind v4 (peer range ^4.0.0) in the host app.",
    )
  }

  if (typeof mod.__unstable__loadDesignSystem !== "function") {
    throw new Error(
      "lint-tailwind: Tailwind's `__unstable__loadDesignSystem` is unavailable. This linter depends on a " +
        "Tailwind v4 internal; pin `tailwindcss` to a compatible 4.x — the internal API likely changed in your version.",
    )
  }

  return mod as TailwindModule
}

const loadDesignSystem = async (): Promise<DesignSystem> => {
  const tailwind = await importTailwind()
  const cssPath = resolve("src/app.css")
  const css = readFileSync(cssPath, "utf-8")

  return tailwind.__unstable__loadDesignSystem(css, {
    base: dirname(cssPath),
    loadStylesheet: async (id: string, base: string) => {
      let p: string
      try {
        p = resolve(base, id)
        readFileSync(p) // test existence
      } catch {
        // Resolve bare specifiers (e.g. "tailwindcss") via node_modules
        const specifier = id.endsWith(".css") ? id : `${id}/index.css`
        p = require.resolve(specifier)
      }
      return { path: p, base: dirname(p), content: readFileSync(p, "utf-8") }
    },
  })
}

// ---------------------------------------------------------------------------
// 2. Arbitrary Value Checker
// ---------------------------------------------------------------------------

const spacingProps = new Set([
  "w",
  "h",
  "min-w",
  "max-w",
  "min-h",
  "max-h",
  "size",
  "p",
  "px",
  "py",
  "pt",
  "pr",
  "pb",
  "pl",
  "m",
  "mx",
  "my",
  "mt",
  "mr",
  "mb",
  "ml",
  "gap",
  "gap-x",
  "gap-y",
  "top",
  "right",
  "bottom",
  "left",
  "inset",
  "inset-x",
  "inset-y",
  "scroll-m",
  "scroll-mx",
  "scroll-my",
  "scroll-mt",
  "scroll-mr",
  "scroll-mb",
  "scroll-ml",
  "scroll-p",
  "scroll-px",
  "scroll-py",
  "scroll-pt",
  "scroll-pr",
  "scroll-pb",
  "scroll-pl",
  "basis",
])

const arbitraryPxRe = /^([\w-]+)-\[(\d+(?:\.\d+)?)px\]$/

const createChecker = (ds: DesignSystem) => {
  const spacingRem = parseFloat(ds.resolveThemeValue("--spacing") ?? "0.25")
  const unitPx = spacingRem * 16

  // Strategy B cache: named CSS declarations → named class
  let namedCssMap: Map<string, string> | null = null

  const extractDeclarations = (css: string): string => {
    const open = css.indexOf("{")
    const close = css.lastIndexOf("}")
    if (open === -1 || close === -1) return css
    return css
      .slice(open + 1, close)
      .replace(/\s+/g, " ")
      .trim()
  }

  const buildNamedCssMap = (): Map<string, string> => {
    const map = new Map<string, string>()
    const classList = ds.getClassList()
    const names: string[] = []
    for (const [cls] of classList) {
      if (!cls.includes("[") && !cls.includes("/")) names.push(cls)
    }
    const cssResults = ds.candidatesToCss(names)
    for (let i = 0; i < names.length; i++) {
      const css = cssResults[i]
      const name = names[i]
      if (css && name) map.set(extractDeclarations(css), name)
    }
    return map
  }

  return function check(cls: string): string | null {
    // Strategy A: pixel values on spacing props
    const pxMatch = cls.match(arbitraryPxRe)
    if (pxMatch) {
      const [, prefix, pxStr] = pxMatch
      if (prefix === undefined || pxStr === undefined) return null
      if (!spacingProps.has(prefix)) return null

      const px = parseFloat(pxStr)
      const units = px / unitPx
      // Accept integers and .25/.5/.75 increments
      const rounded = Math.round(units * 4) / 4
      if (Math.abs(units - rounded) > 0.001) return null

      const candidate = `${prefix}-${rounded}`
      const result = ds.candidatesToCss([candidate])
      if (result[0]) return candidate
    }

    // Strategy B: non-px arbitrary values (rem, calc, etc.)
    if (/^[\w-]+-\[.+\]$/.test(cls) && !arbitraryPxRe.test(cls)) {
      const arbCss = ds.candidatesToCss([cls])
      if (!arbCss[0]) return null

      if (!namedCssMap) namedCssMap = buildNamedCssMap()
      const decl = extractDeclarations(arbCss[0])
      const named = namedCssMap.get(decl)
      if (named && named !== cls) return named
    }

    return null
  }
}

// ---------------------------------------------------------------------------
// 3. Class Extractor — Svelte AST
// ---------------------------------------------------------------------------

type SvelteNode = {
  type: string
  name?: string
  value?: SvelteNode[] | SvelteNode | boolean | string
  data?: string
  expression?: SvelteNode
  callee?: SvelteNode
  arguments?: SvelteNode[]
  children?: SvelteNode[]
  fragment?: SvelteNode
  instance?: SvelteNode
  body?: SvelteNode[]
  elements?: SvelteNode[]
  properties?: SvelteNode[]
  key?: SvelteNode
  quasis?: SvelteNode[]
  start?: number
  end?: number
  raw?: string
  [key: string]: unknown
}

const getCalleeName = (node: SvelteNode): string | null => {
  if (node.type === "Identifier") return node.name as string
  if (node.type === "MemberExpression" && node.property) {
    return (node.property as SvelteNode).name as string
  }
  return null
}

const utilityCallees = new Set(["cn", "clsx", "cva", "tv", "twMerge", "cx", "classnames", "twJoin"])

const extractStringLiterals = (node: SvelteNode): string[] => {
  const results: string[] = []
  if (node.type === "Literal" && typeof node.value === "string") {
    results.push(node.value as string)
  } else if (node.type === "TemplateLiteral" && node.quasis) {
    for (const q of node.quasis) {
      if (q.value && typeof (q.value as { raw?: string }).raw === "string") {
        results.push((q.value as { raw: string }).raw)
      }
    }
  } else if (node.type === "ConditionalExpression") {
    if (node.consequent) results.push(...extractStringLiterals(node.consequent as SvelteNode))
    if (node.alternate) results.push(...extractStringLiterals(node.alternate as SvelteNode))
  } else if (node.type === "ObjectExpression" && node.properties) {
    // Handle tv({ base: "...", variants: { x: { y: "..." } } })
    for (const prop of node.properties) {
      if (prop.type === "Property" && prop.value) {
        results.push(...extractStringLiterals(prop.value as SvelteNode))
      }
    }
  } else if (node.type === "ArrayExpression" && node.elements) {
    for (const el of node.elements) {
      if (el) results.push(...extractStringLiterals(el))
    }
  }
  return results
}

const extractCallExprStrings = (node: SvelteNode): string[] => {
  if (node.type !== "CallExpression" || !node.callee) return []
  const name = getCalleeName(node.callee)
  if (!name || !utilityCallees.has(name)) return []
  const results: string[] = []
  for (const arg of node.arguments ?? []) {
    results.push(...extractStringLiterals(arg))
  }
  return results
}

const walkAst = (node: SvelteNode, visitor: (n: SvelteNode) => void): void => {
  visitor(node)
  for (const key of Object.keys(node)) {
    const child = node[key]
    if (child && typeof child === "object" && !Array.isArray(child) && (child as SvelteNode).type) {
      walkAst(child as SvelteNode, visitor)
    } else if (Array.isArray(child)) {
      for (const item of child) {
        if (item && typeof item === "object" && (item as SvelteNode).type) {
          walkAst(item as SvelteNode, visitor)
        }
      }
    }
  }
}

const lineColFromOffset = (source: string, offset: number): { line: number; col: number } => {
  let line = 1
  let col = 1
  for (let i = 0; i < offset && i < source.length; i++) {
    if (source[i] === "\n") {
      line++
      col = 1
    } else {
      col++
    }
  }
  return { line, col }
}

const extractClassesSvelte = (source: string): ClassRegion[] => {
  let ast: SvelteNode
  try {
    const { parse } = require("svelte/compiler") as {
      parse: (s: string, o: { modern: boolean }) => SvelteNode
    }
    ast = parse(source, { modern: true })
  } catch {
    // Fall back to regex for files that fail to parse
    return extractClassesRegex(source)
  }

  const regions: ClassRegion[] = []

  walkAst(ast, (node) => {
    // Template: class="..." attributes
    if (node.type === "Attribute" && node.name === "class" && Array.isArray(node.value)) {
      for (const chunk of node.value) {
        if (chunk.type === "Text" && typeof chunk.data === "string" && chunk.start != null) {
          const { line, col } = lineColFromOffset(source, chunk.start)
          regions.push({ text: chunk.data, line, col })
        }
        // Expression: class={cn("...")} or class={cond ? "a" : "b"}
        if (chunk.type === "ExpressionTag" && chunk.expression) {
          const strings = extractCallExprStrings(chunk.expression)
          if (strings.length === 0) {
            // Try direct string literals (class={"..."})
            strings.push(...extractStringLiterals(chunk.expression))
          }
          for (const s of strings) {
            const offset = chunk.start ?? 0
            const { line, col } = lineColFromOffset(source, offset)
            regions.push({ text: s, line, col })
          }
        }
      }
    }

    // Script: cn(), clsx(), tv(), cva() calls
    if (node.type === "CallExpression") {
      const strings = extractCallExprStrings(node)
      for (const s of strings) {
        const offset = (node.start as number) ?? 0
        const { line, col } = lineColFromOffset(source, offset)
        regions.push({ text: s, line, col })
      }
    }
  })

  return regions
}

// ---------------------------------------------------------------------------
// 4. Class Extractor — TypeScript files (regex fallback)
// ---------------------------------------------------------------------------

const classAttrRe = /\bclass(?:Name)?=["'`{]([^"'`}]+)/g
const utilityCallRe = /(?:cn|clsx|tv|cva|twMerge|cx)\(\s*["'`]([^"'`]+)/g
const stringInObjRe = /:\s*["']([^"']+)["']/g

const extractClassesRegex = (source: string): ClassRegion[] => {
  const regions: ClassRegion[] = []
  const lines = source.split("\n")

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (line === undefined) continue
    for (const re of [classAttrRe, utilityCallRe, stringInObjRe]) {
      re.lastIndex = 0
      let m: RegExpExecArray | null = null
      while ((m = re.exec(line)) !== null) {
        const [full, text] = m
        if (full === undefined || text === undefined) continue
        regions.push({
          text,
          line: i + 1,
          col: m.index + full.length - text.length + 1,
        })
      }
    }
  }

  return regions
}

// ---------------------------------------------------------------------------
// 5. File Collection
// ---------------------------------------------------------------------------

const collectFiles = (dir: string, exts: string[]): string[] => {
  const files: string[] = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    if (entry.isDirectory() && entry.name !== "node_modules" && entry.name !== ".svelte-kit") {
      files.push(...collectFiles(full, exts))
    } else if (exts.some((ext) => entry.name.endsWith(ext))) {
      files.push(full)
    }
  }
  return files
}

// ---------------------------------------------------------------------------
// 6. Main
// ---------------------------------------------------------------------------

const arbitraryClassRe = /[\w-]+-\[.+?\]/g

const main = async () => {
  const ds = await loadDesignSystem()
  const check = createChecker(ds)

  const args = process.argv.slice(2)
  const paths =
    args.length > 0
      ? args
      : [
          ...collectFiles(resolve("src"), [".svelte"]),
          ...collectFiles(resolve("src"), [".variants.ts"]),
        ]

  const violations: Violation[] = []

  for (const filePath of paths) {
    const source = readFileSync(filePath, "utf-8")
    const isSvelte = filePath.endsWith(".svelte")
    const regions = isSvelte ? extractClassesSvelte(source) : extractClassesRegex(source)

    for (const region of regions) {
      arbitraryClassRe.lastIndex = 0
      let match: RegExpExecArray | null = null

      while ((match = arbitraryClassRe.exec(region.text)) !== null) {
        const cls = match[0]
        const replacement = check(cls)
        if (replacement) {
          violations.push({
            file: relative(process.cwd(), filePath),
            line: region.line,
            col: region.col + match.index,
            original: cls,
            replacement,
          })
        }
      }
    }
  }

  if (violations.length > 0) {
    console.error(`\n  Found ${violations.length} unnecessary arbitrary value(s):\n`)
    for (const v of violations) {
      console.error(
        `  ${v.file}:${v.line}:${v.col} — "${v.original}" can be written as "${v.replacement}"`
      )
    }
    console.error("")
    process.exit(1)
  } else {
    console.log("  No unnecessary arbitrary values found.")
  }
}

main().catch((err) => {
  console.error("lint-tailwind error:", err.message)
  process.exit(2)
})

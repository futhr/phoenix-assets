#!/usr/bin/env node
/// <reference types="node" />
/**
 * Rejects Svelte files that declare both module and instance script blocks.
 *
 * Usage: phoenix-assets-lint-svelte [paths...]
 *        Defaults to every `.svelte` file below `src/`.
 */

import { type Dirent, readdirSync, readFileSync } from "node:fs"
import { join, relative, resolve } from "node:path"
import { parse } from "svelte/compiler"

interface Violation {
  file: string
  line: number
  count: number
}

const collectFiles = (dir: string): string[] => {
  const files: string[] = []
  let entries: Dirent[]

  try {
    entries = readdirSync(dir, { withFileTypes: true })
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return files
    throw error
  }

  for (const entry of entries) {
    const path = join(dir, entry.name)
    if (entry.isDirectory() && entry.name !== "node_modules" && entry.name !== ".svelte-kit") {
      files.push(...collectFiles(path))
    } else if (entry.name.endsWith(".svelte")) {
      files.push(path)
    }
  }

  return files
}

const lineAt = (source: string, offset: number): number => source.slice(0, offset).split("\n").length

const inspectFile = (file: string): Violation | null => {
  const source = readFileSync(file, "utf-8")
  const ast = parse(source, { modern: true })
  if (!ast.module || !ast.instance) return null
  const secondScriptStart = Math.max(ast.module.start, ast.instance.start)

  return {
    file: relative(process.cwd(), file),
    line: lineAt(source, secondScriptStart),
    count: 2,
  }
}

const main = (): void => {
  const args = process.argv.slice(2)
  const paths = args.length > 0 ? args.map((path) => resolve(path)) : collectFiles(resolve("src"))
  const violations = paths.map(inspectFile).filter((item) => item !== null)

  if (violations.length === 0) {
    console.log("  Every Svelte file has at most one script block.")
    return
  }

  console.error(`\n  Found ${violations.length} Svelte file(s) with multiple script blocks:\n`)
  for (const violation of violations) {
    console.error(
      `  ${violation.file}:${violation.line} — found ${violation.count} script blocks; keep one and move shared fixtures to a TypeScript module`,
    )
  }
  console.error("")
  process.exit(1)
}

main()

#!/usr/bin/env node
/// <reference types="node" />
/**
 * Parses Svelte files and optionally applies a host-owned single-script policy.
 *
 * Usage: phoenix-assets-lint-svelte [--single-script] [--allow <glob>] [paths...]
 *        Defaults to every `.svelte` file below `src/`.
 */

import { type Dirent, readFileSync, readdirSync, statSync } from "node:fs"
import { join, matchesGlob, relative, resolve, sep } from "node:path"
import { parse } from "svelte/compiler"

interface Violation {
  file: string
  line: number
  count: number
}

interface Options {
  allow: string[]
  paths: string[]
  singleScript: boolean
}

const usage =
  "Usage: phoenix-assets-lint-svelte [--single-script] [--allow <glob>] [paths...]"

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

const normalizePath = (path: string): string => path.split(sep).join("/")

const isAllowed = (file: string, patterns: string[]): boolean => {
  const path = normalizePath(relative(process.cwd(), file))
  return patterns.some((pattern) => matchesGlob(path, pattern))
}

const inspectFile = (file: string, options: Options): Violation | null => {
  const source = readFileSync(file, "utf-8")
  const ast = parse(source, { modern: true })
  if (!options.singleScript || !ast.module || !ast.instance || isAllowed(file, options.allow)) {
    return null
  }
  const secondScriptStart = Math.max(ast.module.start, ast.instance.start)

  return {
    file: relative(process.cwd(), file),
    line: lineAt(source, secondScriptStart),
    count: 2,
  }
}

const parseArgs = (args: string[]): Options => {
  const options: Options = { allow: [], paths: [], singleScript: false }

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index]

    if (arg === "--single-script") {
      options.singleScript = true
    } else if (arg === "--allow") {
      const pattern = args[index + 1]
      if (!pattern || pattern.startsWith("--")) throw new Error(`${usage}\n--allow requires a glob`)
      options.allow.push(normalizePath(pattern))
      index += 1
    } else if (arg?.startsWith("--allow=")) {
      const pattern = arg.slice("--allow=".length)
      if (pattern === "") throw new Error(`${usage}\n--allow requires a glob`)
      options.allow.push(normalizePath(pattern))
    } else if (arg === "--help" || arg === "-h") {
      console.log(usage)
      process.exit(0)
    } else if (arg?.startsWith("-")) {
      throw new Error(`${usage}\nUnknown option: ${arg}`)
    } else if (arg) {
      options.paths.push(arg)
    }
  }

  if (!options.singleScript && options.allow.length > 0) {
    throw new Error(`${usage}\n--allow only applies with --single-script`)
  }

  return options
}

const expandPaths = (paths: string[]): string[] => {
  const inputs = paths.length > 0 ? paths.map((path) => resolve(path)) : [resolve("src")]

  return inputs
    .flatMap((path) => (statSync(path, { throwIfNoEntry: false })?.isDirectory() ? collectFiles(path) : [path]))
    .sort()
}

const main = (): void => {
  const options = parseArgs(process.argv.slice(2))
  const violations = expandPaths(options.paths)
    .map((path) => inspectFile(path, options))
    .filter((item) => item !== null)

  if (violations.length === 0) {
    console.log(
      options.singleScript
        ? "  Svelte files satisfy the configured single-script policy."
        : "  Svelte files parsed successfully; module and instance scripts are supported.",
    )
    return
  }

  console.error(`\n  Found ${violations.length} Svelte file(s) with multiple script blocks:\n`)
  for (const violation of violations) {
    console.error(
      `  ${violation.file}:${violation.line} — found ${violation.count} script blocks; forbidden by --single-script`,
    )
  }
  console.error("")
  process.exit(1)
}

main()

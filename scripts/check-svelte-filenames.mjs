// Svelte component filenames are kebab-case throughout the workspace. Keeping
// this mechanical prevents case-sensitive import failures and makes component
// paths predictable across packages and host operating systems.
//
// Run: node scripts/check-svelte-filenames.mjs (wired into `mix check`)
import { readdir } from "node:fs/promises"
import { join, relative } from "node:path"
import { fileURLToPath } from "node:url"

const root = fileURLToPath(new URL("..", import.meta.url))
const npmRoot = join(root, "npm")
const ignoredDirectories = new Set([".svelte-kit", "coverage", "dist", "node_modules"])
const kebabCase = /^[a-z0-9]+(?:-[a-z0-9]+)*$/
const violations = []

const componentStem = (filename) => {
  const storiesSuffix = ".stories.svelte"
  if (filename.endsWith(storiesSuffix)) return filename.slice(0, -storiesSuffix.length)

  return filename.slice(0, filename.indexOf(".svelte"))
}

const walk = async (directory) => {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)

    if (entry.isDirectory()) {
      if (!ignoredDirectories.has(entry.name)) await walk(path)
    } else if (entry.name.includes(".svelte") && !kebabCase.test(componentStem(entry.name))) {
      violations.push(relative(root, path))
    }
  }
}

await walk(npmRoot)

if (violations.length > 0) {
  for (const path of violations.sort()) console.error(`${path}: Svelte filename is not kebab-case`)
  process.exit(1)
}

console.log("svelte filenames: clean")

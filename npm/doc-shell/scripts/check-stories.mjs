import { access, readdir } from "node:fs/promises"
import { basename, dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = fileURLToPath(new URL("../src", import.meta.url))
for (const name of await readdir(root)) {
  if (!name.endsWith(".svelte") || name.endsWith(".stories.svelte")) continue
  const story = join(dirname(join(root, name)), `${basename(name, ".svelte")}.stories.svelte`)
  await access(story).catch(() => {
    throw new Error(`Missing Storybook story for ${name}`)
  })
}

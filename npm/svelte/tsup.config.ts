import { defineConfig } from "tsup"

export default defineConfig({
  entry: ["src/index.ts", "src/collection.ts"],
  format: ["esm"],
  dts: true,
  clean: true,
  sourcemap: true,
  external: [
    "svelte",
    "svelte/store",
    "@electric-sql/client",
    "@tanstack/svelte-db",
    "@tanstack/electric-db-collection",
  ],
})

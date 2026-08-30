import { defineConfig } from "tsup"

export default defineConfig({
  entry: ["lint-svelte.ts", "lint-tailwind.ts"],
  format: ["esm"],
  clean: true,
  sourcemap: true,
  external: ["tailwindcss", "svelte", "svelte/compiler"],
})

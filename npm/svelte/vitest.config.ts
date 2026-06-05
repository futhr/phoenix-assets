import { svelte } from "@sveltejs/vite-plugin-svelte"
import { defineConfig } from "vitest/config"

export default defineConfig({
  // The svelte plugin compiles `*.svelte.test.ts` so reactive helpers can be
  // exercised with `$effect`; the `browser` condition resolves Svelte's client
  // runtime (which drives `createSubscriber`).
  plugins: [svelte()],
  resolve: { conditions: ["browser"] },
  test: {
    environment: "happy-dom",
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov"],
      reportsDirectory: "./coverage",
      include: ["src/**/*.ts"],
      // shape-collection.ts is driven by @tanstack/svelte-db, which only resolves
      // under svelte/browser export conditions -- not unit-testable in this
      // runner. It is exercised by the Electric integration, not here.
      exclude: ["src/index.ts", "src/electric/shape-collection.ts", "**/*.d.ts"],
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 75,
        statements: 80,
      },
    },
  },
})

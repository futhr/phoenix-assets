import { defineConfig } from "vitest/config"

// The linter is a CLI (`lint-tailwind.ts` runs `main()` on import and exports
// nothing), so it is covered as a black box: the tests spawn it against fixture
// projects and assert on its reports. No source-coverage thresholds here -- the
// instrumented ≥80% floor lives in the vite and svelte packages.
export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
  },
})

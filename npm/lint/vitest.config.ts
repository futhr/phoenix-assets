import { defineConfig } from "vitest/config"

// The linter is a CLI (`lint-tailwind.ts` runs `main()` on import and exports
// nothing), so it is covered as a black box: the tests spawn it against fixture
// projects and assert on its reports. No source-coverage thresholds here -- the
// instrumented ≥80% floor lives in the vite and svelte packages.
export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    // Each black-box test starts the Tailwind CLI. Shared CI runners can take
    // longer than Vitest's 5-second default while mix check runs in parallel.
    testTimeout: 15_000,
  },
})

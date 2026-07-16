/**
 * `@phoenix-assets/svelte/collection` — the TanStack DB collection helper, kept
 * in a separate entry so the main barrel stays free of the optional `@tanstack/*`
 * peer deps. Import from here (and install `@tanstack/svelte-db` +
 * `@tanstack/electric-db-collection`) only when you need cross-shape joins, the
 * query DSL, or optimistic-write reconciliation; otherwise use `createShapeStore`.
 */
export { createShapeCollection } from "./electric/shape-collection.js"

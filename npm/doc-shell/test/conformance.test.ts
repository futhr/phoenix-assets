import { describe, expect, it } from "vitest"
import type { DocAstElement, NavigationItem, SearchEntry } from "../src/types.js"
import { presentationFixture } from "./fixtures/doc-shell-v1.js"
import { graphProjectorFixture } from "./fixtures/graph-projector.js"

/**
 * The `doc-shell/v1` contract is declared twice — as Elixir types in the
 * `doc_shell` Hex package, and as the interfaces in `src/types.ts` that this
 * renderer consumes. Nothing connected the two, so they drifted: the producers
 * emit keys the renderer never declared, and one `doc_shell` commit bent the
 * *producer* to match the TypeScript, inverting which side is authoritative.
 *
 * It also has two producers that do not emit the same keys, which nothing
 * recorded anywhere. Both are held against the types here, so the contract is
 * the intersection-plus-optionals it actually is rather than whichever producer
 * someone last looked at.
 */

// The fixtures' `satisfies` catches a key a producer emits and we never
// declared. These lists catch the opposite drift — a key we declare as required
// that a producer does not send — which type-checking alone cannot see.
const required = {
  navigation: ["id", "title", "path"] satisfies (keyof NavigationItem)[],
  search: ["id", "title", "content", "path", "audience", "locale"] satisfies (keyof SearchEntry)[],
  ast: ["tag"] satisfies (keyof DocAstElement)[],
}

const optional = {
  navigation: ["children", "kind", "meta"] satisfies (keyof NavigationItem)[],
  search: ["kind", "tokens"] satisfies (keyof SearchEntry)[],
  ast: ["attrs", "content", "meta"] satisfies (keyof DocAstElement)[],
}

const keysIn = (values: object[]) => [...new Set(values.flatMap((value) => Object.keys(value)))]

const astElements = (content: Record<string, unknown[]>): DocAstElement[] =>
  Object.values(content)
    .flat()
    .filter((node): node is DocAstElement => typeof node === "object" && node !== null)

const producers = [
  { name: "doc_shell StaticGenerator", presentation: presentationFixture },
  { name: "host GraphProjector", presentation: graphProjectorFixture },
]

describe.each(producers)("$name emits doc-shell/v1", ({ presentation }) => {
  it("is a v1 artifact with entries to check", () => {
    expect(presentation.schema_version).toBe("doc-shell/v1")
    expect(presentation.navigation.length).toBeGreaterThan(0)
    expect(presentation.search.length).toBeGreaterThan(0)
  })

  it("sends every required navigation key, and nothing undeclared", () => {
    const keys = keysIn(presentation.navigation)

    expect(keys).toEqual(expect.arrayContaining(required.navigation))
    for (const key of keys) {
      expect([...required.navigation, ...optional.navigation]).toContain(key)
    }
  })

  it("sends every required search key, and nothing undeclared", () => {
    const keys = keysIn(presentation.search)

    expect(keys).toEqual(expect.arrayContaining(required.search))
    for (const key of keys) {
      expect([...required.search, ...optional.search]).toContain(key)
    }
  })

  it("sends every required AST key, and nothing undeclared", () => {
    const elements = astElements(presentation.content)
    const keys = keysIn(elements)

    expect(elements.length).toBeGreaterThan(0)
    expect(keys).toEqual(expect.arrayContaining(required.ast))
    for (const key of keys) {
      expect([...required.ast, ...optional.ast]).toContain(key)
    }
  })
})

describe("where the producers differ", () => {
  it("keeps kind, meta, and tokens optional — only StaticGenerator sends them", () => {
    expect(presentationFixture.search[0]).toHaveProperty("tokens")
    expect(presentationFixture.navigation[0]).toHaveProperty("kind")
    expect(graphProjectorFixture.search[0]).not.toHaveProperty("tokens")
    expect(graphProjectorFixture.navigation[0]).not.toHaveProperty("kind")
  })

  // Both producers always send the keys; StaticGenerator sends null when the
  // entry has no facet, so `audience?: string` would reject its every entry.
  it("types audience and locale as nullable rather than optional", () => {
    expect(presentationFixture.search[0]?.audience).toBeNull()
    expect(graphProjectorFixture.search[0]?.audience).toBe("developer")
  })
})

import { describe, expect, it } from "vitest"
import {
  CLASSIFICATIONS,
  DEFAULT_REPORTING_LIMITS,
  FIELD_ROLES,
  FIELD_TYPES,
  VISUALIZATION_KINDS,
} from "../src/reporting/contract.js"

/**
 * This package is a renderer for a contract it does not own. The canonical
 * definition lives upstream in `Refpath.Presentation.Validator`, and the same
 * enum lists are hand-maintained on both sides — a divergence would not fail a
 * build, it would fail a real user's report at decode time.
 *
 * These are the upstream lists, transcribed with their module attribute names
 * so a reviewer can diff them by eye against
 * `refpath/lib/refpath/presentation/validator.ex`. A contract change lands
 * upstream first; this test is what makes the follow-up impossible to forget.
 *
 * The endgame is generating `contract.ts` from the upstream typespecs, at which
 * point this file goes away.
 */
const upstream = {
  // @kinds
  kinds: "number table line area bar scatter heatmap gauge sparkline",
  // @types
  types: "boolean integer float decimal string date time datetime duration",
  // @roles
  roles: "dimension measure time identifier",
  // @classifications
  classifications: "public internal confidential restricted",
}

const words = (list: string) => list.split(" ")

describe("RT.69 contract conformance", () => {
  it("renders exactly the upstream visualization kinds", () => {
    expect([...VISUALIZATION_KINDS].sort()).toEqual(words(upstream.kinds).sort())
  })

  it("accepts exactly the upstream field types", () => {
    expect([...FIELD_TYPES].sort()).toEqual(words(upstream.types).sort())
  })

  it("accepts exactly the upstream field roles", () => {
    expect([...FIELD_ROLES].sort()).toEqual(words(upstream.roles).sort())
  })

  it("accepts exactly the upstream classifications", () => {
    expect([...CLASSIFICATIONS].sort()).toEqual(words(upstream.classifications).sort())
  })

  // `maxBytes` mirrors `Refpath.Presentation.@max_json_bytes`; the rest mirror
  // `Refpath.Presentation.Validator.@default_limits`. A renderer that decodes to
  // a looser bound than the producer validates against accepts envelopes the
  // owner never blessed.
  it("enforces the upstream size and complexity limits", () => {
    expect(DEFAULT_REPORTING_LIMITS).toMatchObject({
      maxBytes: 262_144,
      maxPanels: 32,
      maxFields: 64,
      maxRows: 10_000,
      maxCellBytes: 8_192,
      maxDepth: 64,
    })
  })
})

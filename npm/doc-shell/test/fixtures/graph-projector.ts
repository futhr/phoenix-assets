import type { DocShellPresentation } from "../../src/types.js"

/**
 * The shape a host's `DocShell.Presentation.GraphProjector` emits — the second
 * producer of `doc-shell/v1`, and the reason several keys in the contract are
 * optional. It sends no `kind`, no `meta`, and no `tokens`, and it always sends
 * a real `audience`/`locale` rather than null.
 *
 * Transcribed from the projector's own map literals (its `navigation/2`,
 * `navigation_entry/2`, `search_entry/2` and `backlinks/2` clauses) rather than
 * captured from a run, because producing it needs a populated graph.
 */
export const graphProjectorFixture = {
  schema_version: "doc-shell/v1",
  navigation: [
    {
      id: "section:Documentation",
      title: "Documentation",
      path: "/en/docs/getting-started",
      children: [
        {
          id: "getting-started",
          title: "Getting started",
          path: "/en/docs/getting-started",
          children: [],
        },
      ],
    },
  ],
  search: [
    {
      id: "getting-started",
      title: "Getting started",
      content: "Install the package and run the generator.",
      path: "/en/docs/getting-started",
      audience: "developer",
      locale: "en",
    },
  ],
  content: {
    "getting-started": [
      { tag: "p", attrs: {}, content: ["Install the package and run the generator."], meta: {} },
    ],
  },
  backlinks: {
    "getting-started": [{ id: "overview", title: "Overview", path: "/en/docs/overview" }],
  },
} satisfies DocShellPresentation

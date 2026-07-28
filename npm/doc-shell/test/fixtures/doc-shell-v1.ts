import type { DocShellPresentation } from "../../src/types.js"

/**
 * A verbatim slice of `doc_shell`'s real emitted artifacts — the union of
 * `priv/doc_shell/public/{navigation,search-index,content}.json` after
 * `mix doc_shell.build`. Keep it verbatim: its worth is that it is what the
 * producer actually writes, not what we believe it writes.
 *
 * `satisfies` is load-bearing. TypeScript applies an excess-property check to
 * an object literal, so a key the producer emits and `src/types.ts` does not
 * declare fails the build here, rather than surfacing as a runtime surprise in
 * a host.
 */
export const presentationFixture = {
  schema_version: "doc-shell/v1",
  navigation: [
    {
      children: [],
      id: "DocShell",
      kind: "module",
      meta: {
        language: "elixir",
        members: [
          {
            arity: 0,
            doc: "The current renderer-neutral artifact schema version.",
            kind: "function",
            metadata: {
              source_annos: [[13, 7]],
            },
            name: "schema_version",
            signatures: ["schema_version()"],
          },
        ],
        module: "DocShell",
      },
      path: "/docs/module/DocShell",
      title: "DocShell",
    },
    {
      children: [],
      id: "DocShell.Artifact",
      kind: "module",
      meta: {
        language: "elixir",
        members: [
          {
            arity: 2,
            doc: "Wraps a payload in the public artifact envelope.",
            kind: "function",
            metadata: {
              defaults: 1,
              source_annos: [[6, 7]],
            },
            name: "envelope",
            signatures: ["envelope(payload, generated_at \\\\ DateTime.utc_now())"],
          },
          {
            arity: 1,
            doc: "Reads and validates a JSON artifact envelope.",
            kind: "function",
            metadata: {
              source_annos: [[26, 7]],
            },
            name: "read",
            signatures: ["read(path)"],
          },
          {
            arity: 2,
            doc: "Writes a JSON artifact atomically.",
            kind: "function",
            metadata: {
              source_annos: [[16, 7]],
            },
            name: "write",
            signatures: ["write(path, payload)"],
          },
        ],
        module: "DocShell.Artifact",
      },
      path: "/docs/module/DocShell.Artifact",
      title: "DocShell.Artifact",
    },
  ],
  search: [
    {
      audience: null,
      content: "Renderer-neutral documentation generation and optional web serving. Hosts config",
      id: "DocShell",
      kind: "module",
      locale: null,
      path: "/docs/module/DocShell",
      title: "DocShell",
      tokens: ["renderer", "neutral", "documentation", "generation"],
    },
    {
      audience: null,
      content: "Writes and reads versioned DocShell JSON artifacts.",
      id: "DocShell.Artifact",
      kind: "module",
      locale: null,
      path: "/docs/module/DocShell.Artifact",
      title: "DocShell.Artifact",
      tokens: ["writes", "and", "reads", "versioned"],
    },
  ],
  content: {
    DocShell: [
      {
        attrs: {},
        content: ["Renderer-neutral documentation generation and optional web serving."],
        meta: {},
        tag: "p",
      },
      {
        attrs: {},
        content: [
          "Hosts configure the package under ",
          {
            attrs: {
              class: "inline",
            },
            content: [":doc_shell"],
            meta: {
              line: 3,
            },
            tag: "code",
          },
          "; generated artifacts conform\nto the versioned ",
          {
            attrs: {
              class: "inline",
            },
            content: ["doc-shell/v1"],
            meta: {
              line: 4,
            },
            tag: "code",
          },
          " public contract.",
        ],
        meta: {},
        tag: "p",
      },
    ],
  },
} satisfies DocShellPresentation

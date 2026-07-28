import type { DocShellPresentation, OpenApiDocument, OperationEntry } from "./types.js"

export const presentation: DocShellPresentation = {
  schema_version: "doc-shell/v1",
  navigation: [{ id: "intro", title: "Introduction", path: "/docs/intro" }],
  search: [
    {
      id: "intro",
      title: "Introduction",
      content: "Start here",
      path: "/docs/intro",
      audience: null,
      locale: null,
    },
  ],
  content: {
    intro: [
      { tag: "h2", content: "Start here" },
      { tag: "callout", attrs: { title: "Note" }, content: "Shared content" },
    ],
  },
  backlinks: { intro: [{ id: "api", title: "API", path: "/docs/api" }] },
}

export const spec: OpenApiDocument = {
  info: { title: "Example API", version: "1.0.0" },
  paths: {
    "/users": {
      get: {
        operationId: "users",
        summary: "List users",
        tags: ["Users"],
        responses: {
          "200": {
            description: "Success",
            content: { "application/json": { schema: { type: "object", example: { users: [] } } } },
          },
        },
      },
    },
  },
}
export const operation: OperationEntry = {
  id: "users",
  method: "GET",
  path: "/users",
  tags: ["Users"],
  operation: spec.paths?.["/users"]?.get ?? {},
}

import type { DocAstNode, DocShellSite, SitePage } from "./types.js"

const digest = (character: string) => `sha256:${character.repeat(64)}`

const content: DocAstNode[] = [
  { tag: "p", content: ["A portable documentation page rendered from the shared contract."] },
  { tag: "h2", attrs: { id: "install" }, content: ["Install"] },
  {
    tag: "pre",
    content: [{ tag: "code", attrs: { class: "language-elixir" }, content: ["mix deps.get\n"] }],
  },
  { tag: "h2", attrs: { id: "configure" }, content: ["Configure"] },
  {
    tag: "callout",
    attrs: { title: "Keep the fallback" },
    content: ["The article remains readable before JavaScript starts."],
  },
  {
    tag: "table",
    content: [
      {
        tag: "thead",
        content: [
          {
            tag: "tr",
            content: [
              { tag: "th", content: ["Capability"] },
              { tag: "th", content: ["State"] },
            ],
          },
        ],
      },
      {
        tag: "tbody",
        content: [
          {
            tag: "tr",
            content: [
              { tag: "td", content: ["Static HTML"] },
              { tag: "td", content: ["Ready"] },
            ],
          },
        ],
      },
    ],
  },
]

const guide: SitePage = {
  id: "guide",
  collection_id: "example",
  document_id: "guide",
  kind: "guide",
  route: "/docs/guide/",
  title: "Build a portable documentation site",
  description: "The same admitted content works in Svelte, LiveView, and static HTML.",
  locale: "en",
  template: "document",
  content,
  content_digest: digest("b"),
  source_url: "https://example.test/source",
  edit_url: "https://example.test/edit",
  source_revision: "abc123",
  package_version: "1.0.0",
  last_modified: "2026-09-20",
  status: "stable",
  breadcrumbs: [{ title: "Documentation", path: "/docs/guide/" }],
  headings: [
    { id: "install", title: "Install", level: 2 },
    { id: "configure", title: "Configure", level: 2 },
  ],
  tags: ["static", "live"],
  metadata: {},
  "navigation?": true,
  "search?": true,
  banner: { label: "Stable release" },
  requirements: [],
}

export const siteFixture: DocShellSite = {
  schema_version: "doc-shell-site/v1",
  generation_id: "storybook-1",
  cohort_digest: digest("a"),
  profile: "public",
  title: "Example documentation",
  base_path: "/docs",
  default_locale: "en",
  locales: ["en"],
  pages: { guide },
  routes: { [guide.route]: guide.id },
  navigation: [
    {
      id: "guide",
      title: "Build a documentation site",
      path: guide.route,
      children: [{ id: "install", title: "Install", path: `${guide.route}#install`, children: [] }],
    },
  ],
  search: [
    {
      id: "guide:install",
      page_id: guide.id,
      route: `${guide.route}#install`,
      title: guide.title,
      section: "Install",
      text: "Install dependencies and build the portable documentation site.",
      locale: "en",
      kind: "guide",
      collection: "example",
      version: "1.0.0",
      tags: ["static"],
      status: "stable",
    },
  ],
  redirects: {},
  metadata: {},
}

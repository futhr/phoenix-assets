# phoenix_assets usage rules

`phoenix_assets` is an opinionated, batteries-included asset runtime for Phoenix:
SvelteKit + Vite + Tailwind v4 + Storybook + ElectricSQL + Phoenix PubSub +
localization + Ash→TypeScript types, wired together. It supervises Vite and
Storybook, generates typed frontend contracts from your backend, links everything
into one asset graph, and validates the production manifest.

## The golden path

- **Do not write a preset module.** The full stack is the default
  (`PhoenixAssets.Presets.Svelte`). Configure the app and name your declaration
  modules; that's it:

  ```elixir
  # config/config.exs
  config :phoenix_assets,
    otp_app: :my_app,
    endpoint: MyAppWeb.Endpoint,
    router: MyAppWeb.Router

  config :phoenix_assets, :stack,
    shapes: MyApp.Assets.ElectricShapes,
    topics: MyApp.Assets.PubSubTopics,
    types: MyApp.Assets.Types
  ```

- **Supervise it.** Add the children to your application tree:

  ```elixir
  children = [...] ++ PhoenixAssets.child_specs()
  ```

  In production this starts only the manifest server; in dev (when
  `config :phoenix_assets, :dev, enabled: true`) it also supervises Vite,
  Storybook, and the generated-file watcher.

## Declaration modules (the backend contract)

Each is a small DSL. The declarations are metadata only — the actual server work
(Ash queries, policies, tenancy) stays in your controllers.

```elixir
defmodule MyApp.Assets.ElectricShapes do
  use PhoenixAssets.Electric.Shapes
  shape :portfolios, route: "/shapes/portfolios", type: "PortfolioRow"
  # Route placeholders become required, typed keys on the generated factory;
  # `params:` is optional documentation, validated at compile time to match.
  shape :user_portfolios, route: "/shapes/users/:user_id/portfolios",
        type: "PortfolioRow", params: [:user_id]
end

defmodule MyApp.Assets.Commands do
  use PhoenixAssets.Commands.Definitions
  # Reads are shapes; everything that changes state is a command. Declaring the
  # error codes is the point: the generated client returns a discriminated
  # result, so a call site cannot read the payload without handling failure.
  command :publish_portfolio,
    route: "/api/portfolios/:id/publish",
    method: :post,
    params: [id: :string],
    body: [note: :string],
    result: "PortfolioRow",
    errors: [:already_published, :portfolio_not_found]
end

defmodule MyApp.Assets.Session do
  use PhoenixAssets.Session.Fields
  # Who is asking, declared once, so neither side re-derives it by hand.
  route "/api/session"
  field :user_id, :string
  field :organization_id, :string
  field :role, :string, values: ["owner", "admin", "member"]
  field :platform_admin, :boolean
end

defmodule MyApp.Assets.PubSubTopics do
  use PhoenixAssets.PubSub.Topics
  topic :portfolio, pattern: "portfolio:{id}",
        events: [updated: "PortfolioRow", deleted: %{id: :string}]
end

defmodule MyApp.Assets.Types do
  use PhoenixAssets.Types.Schema
  type "PortfolioRow", resource: MyApp.Portfolio, only: :public
end
```

## Generated contracts

`mix phoenix_assets.gen` writes typed TypeScript into `assets/src/generated/`:
`routes.ts` (endpoint helpers for `/shapes/*` and `/api/*` — **page routes are
SvelteKit's, never generated**), `env.ts`, `electric.ts`, `commands.ts`,
`session.ts`, `pubsub.ts`, `locales.ts`, `types.ts`. The frontend imports them through `$phoenix/*` virtual
modules (`$phoenix/routes`, `$phoenix/electric`, …) provided by the Vite plugin.

Rules to rely on:

- **Generation is deterministic** and content-gated (no write when output is
  byte-identical). `mix phoenix_assets.gen --check` fails on drift — wire it into
  `assets.deploy` as a CI gate.
- **A command result is a value, never an exception.** `runCommand` resolves to
  `{ ok: true, data }` or `{ ok: false, error, status }`; a network failure and
  an error code this build does not know both degrade to `"unknown_error"`
  rather than escaping as an untyped string or a rejected promise.
- **Sensitive and non-public Ash fields are excluded** from generated row types
  automatically (`sensitive?: true` and `public?: false` never reach the client).
  A doctor check warns when an exposed field is also field-policy-gated.
- Run `mix phoenix_assets.doctor` (add `--production` in CI) to validate config,
  routes, manifest presence, and freshness.

## Frontend packages

- `@phoenix-assets/vite` — the Vite plugin (`phoenixAssets`), `$phoenix/*` virtual
  modules, HMR bridge, PO loader, graph emitter. Add it to `vite.config.js`.
- `@phoenix-assets/svelte` — typed runtime helpers: `createShapeStore`,
  `authHeaders`/`createShapeUrl` (used by the generated `$phoenix/electric`
  client), `runCommand` (used by the generated `$phoenix/commands` client), the
  event modifiers (`debounce`, `throttle`, `once`, `stopPropagation`,
  `preventDefault`, `self`), `matchEvent`, `resolveLocale`, and `configureShapeAuth` to point the
  shape clients at your app's token key. `createShapeCollection` (TanStack DB)
  lives behind the `@phoenix-assets/svelte/collection` subpath so the main
  barrel stays free of the optional `@tanstack/*` peers.
- `@phoenix-assets/svelte/reporting` — strict portable-report decoding, the
  closed LayerChart-backed compiler/components, evidence states, and accessible
  table twins. Pass only the renderer-neutral contract. Product code supplies
  semantic CSS tokens and domain chrome; it does not import LayerChart directly
  or persist renderer option bags.

## Linting & formatting (host apps)

Use **Biome** for the frontend (the same linter `phoenix_assets` uses — no
ESLint/Prettier). The stack ships the shared config + the Tailwind linter as
`@phoenix-assets/lint`:

```bash
pnpm add -D @phoenix-assets/lint @biomejs/biome tailwindcss svelte
```

- **Biome:** `biome.json` → `{ "extends": ["@phoenix-assets/lint/biome.base.json"] }`,
  then layer your app-specific excludes/overrides on top. The base sets
  Svelte-aware rules (a `**/*.svelte` override disabling `useConst`,
  `useImportType`, `noUnusedVariables`, `noUnusedImports` — Biome false-positives
  on those in Svelte).
- **Tailwind v4 hygiene:** add a `lint:tw` script running the compiled
  `phoenix-assets-lint-tailwind` binary the package ships (or invoke it ad hoc with
  `pnpm exec phoenix-assets-lint-tailwind`) — it flags arbitrary values with a
  standard equivalent (`w-[180px]` → `w-45`). Wire both into CI.

## When you genuinely need to deviate

Write a module with `use PhoenixAssets.Preset`, list `integration/2` calls, and
set it as `config :phoenix_assets, preset: MyApp.Assets.Stack`. Start by copying
`PhoenixAssets.Presets.Svelte`. Ordering is resolved at compile time (a cycle or
missing hard dependency is a compile error).

## Don't

- Don't hand-write a preset just to use the standard stack — omit `:preset`.
- Don't generate page routes or hand-copy contract types — let the generators own
  them and import from `$phoenix/*`.
- Don't put secrets in `config :phoenix_assets, :env, expose: [...]` — only listed
  keys are emitted, but treat the allow-list as public.

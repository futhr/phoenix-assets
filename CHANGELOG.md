# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.1.0](https://github.com/futhr/phoenix-assets/compare/v0.1.0...v0.1.0) (2026-08-24)
### Breaking Changes:

* make the stack tunable without a preset by futhr

* gate the Tidewave surface behind :dev_intelligence by futhr

* dev: exec dev-server binaries directly and honor configured host/port by futhr

* plugin: consume vite_config into the graph; drop runtime_modules by futhr

* routes: controller-aware collision names and configurable prefixes by futhr

* dsl: validate declarations at compile time by futhr

* graph: move the default graph path out of the public static dir by futhr

* replace Jason with the stdlib JSON module by futhr

* deps: require elixir ~> 1.18 and the current phoenix stack by futhr



### Features:

* enums: discover enums from dependency applications by futhr

* upstream the five things every host rebuilt by futhr

* generate TypeScript from Elixir typespecs through the pipeline by futhr

* reporting: make the composed-panel door first-class by futhr

* describe wrapped command payloads by futhr

* add declarative event modifiers by futhr

* generate the session context contract by futhr

* generate typed command clients by futhr

* expose report table views by futhr

* page large report tables by futhr

* add governed report drills by futhr

* generate TypeScript from Elixir typespecs by futhr

* add shared DocShell renderer package by futhr

* reporting: add portable report renderer contract by futhr

* render portable heatmaps by futhr

* add shared portable report renderer by futhr

* lint: ship Tailwind linter as a CLI by futhr

* CDN asset_url, hot-file dev URLs, Early Hints, speculation rules by futhr

* telemetry: emit every documented event by futhr

* doctor: node_modules, vite-binary, bundle-budget, and source-map checks by futhr

* electric: type route placeholders as required shape params by futhr

* graph: canonical ordered JSON encoder by futhr

* make the gettext scan root configurable by futhr

* carry auth headers on generated Electric shape clients by futhr

* configurable shape auth and a TanStack-free barrel by futhr

* add :spa serve_mode with an SPA-aware manifest check by futhr

* render Ash.Type.Enum modules as string-literal unions by futhr

* add the shared lint package by futhr

* add the svelte runtime helpers by futhr

* add the vite plugin with $phoenix virtual modules by futhr

* add the doctor, clean, and graph tasks by futhr

* add the igniter installer by futhr

* add the gen task and its subgenerators by futhr

* expose dev tools to tidewave by futhr

* add the production doctor by futhr

* emit telemetry spans for long-running work by futhr

* serve assets through a plug by futhr

* emit hashed asset tags from components by futhr

* ship the default svelte preset by futhr

* integrate sveltekit by futhr

* integrate storybook off the shared vite config by futhr

* wire tailwind v4 through vite by futhr

* integrate gettext localization by futhr

* integrate phoenix pubsub topics by futhr

* integrate electricsql shapes by futhr

* supervise vite and storybook as otp children by futhr

* walk ash resources into typescript types by futhr

* generate typescript from the graph by futhr

* generate route and env contracts by futhr

* watch generated files for drift by futhr

* write generated files deterministically by futhr

* add a few mix helpers by futhr

* serve the manifest from a genserver by futhr

* read the vite manifest by futhr

* compile the graph to a zero-cost module by futhr

* build the asset graph by futhr

* add the top-level module and otp app by futhr

* assemble the engine by futhr

* add the preset behaviour by futhr

* resolve plugins through a small engine by futhr

* add the asset context by futhr

* add the config layer by futhr

### Bug Fixes:

* release: align package metadata and initial release flow by Tobias Bohwalli

* harden release identity boundaries by Tobias Bohwalli

* svelte: enforce kebab-case component filenames by Tobias Bohwalli

* harden security, concurrency, and releases by Tobias Bohwalli

* vite: load Gettext catalogs before module parsing by futhr

* stop clean from deleting files it did not generate by futhr

* doc-shell: type doc-shell/v1 the way its producers emit it by futhr

* resolve phx_new for the install task test by futhr

* expose report chart summaries by futhr

* reporting: improve portable report accessibility by futhr

* reporting: fall back safely for single-point trend charts by futhr

* make report relationships instance safe by futhr

* harden portable report decoding by futhr

* npm: remove stale locale paths and harden runtime helpers by futhr

* harden generation and production validation by futhr

* npm: harden Vite and Svelte runtime helpers by futhr

* harden asset pipeline validation and runtime checks by futhr

* surface silent pipeline failures; green the mix check gate by futhr

* dev: strict task options; the operator surface degrades instead of crashing by futhr

* watcher: reload code before regenerating; atomic writes; drop dead mode field by futhr

* manifest,localize: uniform missing-key behavior and honest default locale by futhr

* sveltekit: param segments contribute to graph page keys by futhr

* ts: sanitise reserved-word params, quote non-identifier keys, handle globs by futhr

* types: make the walker total and the policy safety net honest by futhr

* routes: make generated route-name dedup collision-aware by futhr

* vite: unescape tab sequences in the PO loader by futhr

* svelte: match cookie names literally in shape auth lookup by futhr

* run supervised Vite directly by default by futhr

* type-check the tailwind linter by futhr

### Performance Improvements:

* defer mobile report panels by futhr

# DocShell renderer implementation plan

This tracker implements
[PHA.01](../specs/PHA.01-doc-shell-renderers.md) after the corresponding
`doc-shell-site/v1` package is available from DocShell.

| Package | Status | Requires | Deliverable | Acceptance |
| --- | --- | --- | --- | --- |
| PHA-P01 | planned | DSH-P03/P06 | Import the upstream conformance corpus and add a renderer capability manifest | PHA-V01/V03; schema and fixture drift fail CI |
| PHA-P02 | planned | PHA-P01 | Split URL, search, theme, navigation, copy, tabs and enhancement lifecycle into `@phoenix-assets/doc-shell/browser` | PHA-V02; Svelte renderer remains green |
| PHA-P03 | planned | PHA-P01/P02 | Add optional DocShell dependency and `PhoenixAssets.DocShell.Ast` | PHA-V01/V07/V08; no-optional compile remains green |
| PHA-P04 | planned | PHA-P03 | Add HEEx shell, navigation, breadcrumbs, table of contents, provenance and reading-flow components | PHA-V03–V07 |
| PHA-P05 | planned | PHA-P03/P04 | Add directive, code, Mermaid fallback and browser enhancement components | PHA-V03/V05–V08 |
| PHA-P06 | planned | PHA-P03–P05 | Add OpenAPI reference and disabled-by-default request panel | PHA-V03/V07/V08 |
| PHA-P07 | planned | PHA-P02–P06; DSH-P07 | Implement `PhoenixAssets.DocShell.StaticRenderer` and packaged hashed assets | PHA-V04/V11/V12 |
| PHA-P08 | planned | PHA-P02–P07 | Add shared JSON/Pagefind search integration and LiveView refresh hook | PHA-V05/V09; pinned Pagefind build and lazy chunk evidence |
| PHA-P09 | planned | PHA-P04–P08 | Complete responsive, theme, locale, direction and accessibility behavior | PHA-V05/V06/V10 |
| PHA-P10 | planned | PHA-P01–P09 | Qualify both renderers, archives and fresh consumers across supported runtimes | PHA-V01–V12 and `mix check` |

## Build order rules

- Changes to shared site or fixture shapes land in DocShell first.
- Browser-core extraction keeps the existing Svelte API operational while the
  LiveView adapter is built.
- Each HEEx component lands with its DocShell fixture, Svelte comparison, and
  JavaScript-disabled assertion.
- Static rendering uses the component implementation already accepted for
  LiveView; it does not introduce another template tree.
- Visual snapshots are reviewed inputs. A test command cannot regenerate and
  accept new baselines in one step.
- Generated npm and Hex release artifacts remain outside source status checks
  and are validated from fresh package archives.

## Bundle budgets

The implementation records compressed and uncompressed sizes for the base CSS,
browser core, search, syntax languages, Mermaid, and OpenAPI request panel.
Search, highlighting, Mermaid and request execution load on first use. A normal
article must not load Mermaid or request-panel code. Budget changes require a
measured fixture and an explicit review in the same change.

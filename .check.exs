[
  ## `mix check` is the single quality gate for the whole repo -- Elixir and
  ## frontend. It requires Node + pnpm on PATH for the frontend tools below.
  parallel: true,
  tools: [
    ## --- Elixir ---
    {:compiler, command: "mix compile --warnings-as-errors --force"},
    {:formatter, command: "mix format --check-formatted"},
    {:credo, command: "mix credo --strict"},
    {:doctor, command: "mix doctor"},
    {:mix_audit, command: "mix deps.audit"},
    {:dialyzer, true},

    ## ExUnit with coverage: enforces minimum_coverage (coveralls.json) and
    ## writes cover/lcov.info for Codecov. Replaces the plain :ex_unit tool.
    {:ex_unit, false},
    {:coveralls, command: "mix coveralls.lcov", env: %{"MIX_ENV" => "test"}},

    ## --- Frontend (pnpm): install, then lint / typecheck / test+coverage,
    ## dead-code detection (knip), and package-export correctness (publint + attw) ---
    {:pnpm_install, command: "pnpm install --frozen-lockfile"},
    {:biome, command: "pnpm lint", deps: [:pnpm_install]},
    {:typecheck, command: "pnpm typecheck", deps: [:pnpm_install]},
    {:vitest, command: "pnpm test", deps: [:pnpm_install]},
    {:knip, command: "pnpm knip", deps: [:pnpm_install]},
    {:check_exports, command: "pnpm check:exports", deps: [:pnpm_install]},

    ## --- Deliberately off ---
    {:ex_doc, false},
    {:sobelow, false},
    {:unused_deps, false},
    {:npm_test, false},
    {:gettext, false}
  ]
]

defmodule PhoenixAssets.MixProject do
  @moduledoc false

  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/futhr/phoenix_assets"

  def project do
    [
      app: :phoenix_assets,
      name: "PhoenixAssets",
      description: description(),
      source_url: @source_url,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      deps: deps(),
      dialyzer: dialyzer(),
      package: package(),
      docs: docs()
    ]
  end

  def description do
    "A supervised, type-safe SvelteKit frontend, first-class inside Phoenix."
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.lcov": :test,
        "coveralls.cobertura": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PhoenixAssets.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core runtime (required).
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:plug, "~> 1.14"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.1"},
      {:file_system, "~> 1.0"},
      {:muontrap, "~> 1.5"},
      {:nimble_options, "~> 1.1"},

      # Stack integrations (optional -- a host opts in by adding the ones it uses).
      {:ash, "~> 3.0", optional: true},
      {:ash_typescript, "~> 0.17", optional: true},
      {:phoenix_sync, "~> 0.6", optional: true},
      {:gettext, "~> 0.20", optional: true},
      {:tidewave, "~> 0.5", optional: true},

      # Installer -- powers `mix igniter.install phoenix_assets`. Optional: hosts
      # that scaffold by hand never load it; it is present for this library's own
      # dev/test so the installer compiles and is covered by `Igniter.Test`.
      {:igniter, "~> 0.5", optional: true},

      # Tooling / release.
      {:git_ops, "~> 2.6", only: [:dev], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false},
      {:doctor, "~> 0.22", only: :dev, runtime: false}
    ]
  end

  defp dialyzer do
    [
      flags: [:error_handling, :extra_return, :missing_return, :unmatched_returns, :unknown],
      plt_add_apps: [:mix]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE usage-rules.md)
    ]
  end

  defp docs do
    [
      main: "PhoenixAssets",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Engine: [
          PhoenixAssets.Plugin,
          PhoenixAssets.Plugin.Resolver,
          PhoenixAssets.Preset,
          PhoenixAssets.Engine,
          PhoenixAssets.Config,
          PhoenixAssets.Context
        ],
        "Stack plugins": [
          PhoenixAssets.SvelteKit,
          PhoenixAssets.Tailwind,
          PhoenixAssets.Storybook,
          PhoenixAssets.Electric,
          PhoenixAssets.PubSub,
          PhoenixAssets.Localize,
          PhoenixAssets.Types
        ],
        Presets: [
          PhoenixAssets.Presets.Svelte
        ]
      ]
    ]
  end
end

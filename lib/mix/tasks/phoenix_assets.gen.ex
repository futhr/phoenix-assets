defmodule Mix.Tasks.PhoenixAssets.Gen do
  @moduledoc """
  Generates the typed frontend contracts declared by the configured preset.

      mix phoenix_assets.gen
      mix phoenix_assets.gen --check          # verify without writing; non-zero exit on drift
      mix phoenix_assets.gen --only routes,types

  The `--check` form is the CI drift gate: it fails when the checked-in contracts
  no longer match what the current Phoenix/Ash definitions would produce. Wire it
  into your `assets.deploy` alias before the production bundle is built.
  """
  @shortdoc "Generate typed frontend contracts from Phoenix"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")
    # Strict parsing: a typo'd --check must fail loudly, not silently turn the
    # CI drift gate into a full write.
    {opts, _} = OptionParser.parse!(args, strict: [check: :boolean, only: :string])
    ctx = PhoenixAssets.MixHelpers.context!(env: Mix.env())

    case PhoenixAssets.Generated.generate(ctx, generate_opts(opts)) do
      {:ok, %{written: written, unchanged: unchanged}} ->
        Mix.shell().info(
          "phoenix_assets: #{length(written)} written, #{length(unchanged)} unchanged"
        )

      :ok ->
        Mix.shell().info("phoenix_assets: contracts up to date")

      {:error, {:stale, stale}} ->
        Mix.raise("phoenix_assets: stale contracts:\n" <> Enum.map_join(stale, "\n", &"  #{&1}"))

      {:error, reason} ->
        Mix.raise("phoenix_assets: generation failed: #{inspect(reason)}")
    end
  end

  defp generate_opts(opts), do: [check: opts[:check] || false] ++ only(opts[:only])

  defp only(nil), do: []

  defp only(value) do
    kinds =
      for kind <- String.split(value, ","), kind = String.trim(kind), kind != "" do
        to_kind!(kind)
      end

    [only: kinds]
  end

  defp to_kind!(kind) do
    String.to_existing_atom(kind)
  rescue
    ArgumentError ->
      Mix.raise(
        "phoenix_assets: unknown generator kind #{inspect(kind)} " <>
          "(built-in kinds: routes, env, types, electric, pubsub, locales)"
      )
  end
end

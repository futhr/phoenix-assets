defmodule PhoenixAssets.MixHelpers do
  @moduledoc """
  Shared helpers for the `phoenix_assets.*` Mix tasks.

  Builds the `PhoenixAssets.Context` from the host application's configuration and
  the configured preset, so each task does not repeat the load-config-and-resolve
  dance. Kept free of `Mix` references (the env is passed in) so it remains a
  plain library module.
  """

  alias PhoenixAssets.{Config, Context}

  @doc """
  Builds the context for a Mix task from the host configuration.

  Options: `:env` (the Mix environment, default `:prod`).
  """
  @spec context!(keyword()) :: Context.t()
  def context!(opts \\ []) do
    config = Config.load!()

    Context.new(config,
      env: Keyword.get(opts, :env, :prod),
      plugins: Config.preset_plugins(config)
    )
  end
end

defmodule Mix.Tasks.PhoenixAssets.Clean do
  @moduledoc """
  Removes the generated frontend-contracts directory.

  Useful to force a clean regeneration or to verify the cold-start path where the
  Vite plugin must fall back to typed stubs.
  """
  @shortdoc "Remove generated frontend contracts"

  use Mix.Task

  @impl Mix.Task
  def run(_) do
    ctx = PhoenixAssets.MixHelpers.context!(env: Mix.env())
    dir = PhoenixAssets.Context.generated_path(ctx)
    _ = File.rm_rf!(dir)
    Mix.shell().info("phoenix_assets: removed #{dir}")
  end
end

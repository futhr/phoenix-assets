defmodule Mix.Tasks.PhoenixAssets.Gen.Pubsub do
  @moduledoc "Generates only the PubSub topics contract. See `mix help phoenix_assets.gen`."
  @shortdoc "Generate the pubsub topics contract"

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Mix.Task.run("phoenix_assets.gen", ["--only", "pubsub" | args])
end

defmodule Mix.Tasks.PhoenixAssets.Gen.Electric do
  @moduledoc "Generates only the ElectricSQL shapes contract. See `mix help phoenix_assets.gen`."
  @shortdoc "Generate the electric shapes contract"

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Mix.Task.run("phoenix_assets.gen", ["--only", "electric" | args])
end

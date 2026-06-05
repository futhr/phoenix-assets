defmodule Mix.Tasks.PhoenixAssets.Gen.Env do
  @moduledoc "Generates only the env contract. See `mix help phoenix_assets.gen`."
  @shortdoc "Generate the env contract"

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Mix.Task.run("phoenix_assets.gen", ["--only", "env" | args])
end

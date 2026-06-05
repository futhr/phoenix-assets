defmodule Mix.Tasks.PhoenixAssets.Gen.Types do
  @moduledoc "Generates only the TypeScript types contract. See `mix help phoenix_assets.gen`."
  @shortdoc "Generate the types contract"

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Mix.Task.run("phoenix_assets.gen", ["--only", "types" | args])
end

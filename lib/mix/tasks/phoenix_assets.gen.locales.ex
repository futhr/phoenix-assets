defmodule Mix.Tasks.PhoenixAssets.Gen.Locales do
  @moduledoc "Generates only the locales contract. See `mix help phoenix_assets.gen`."
  @shortdoc "Generate the locales contract"

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Mix.Task.run("phoenix_assets.gen", ["--only", "locales" | args])
end

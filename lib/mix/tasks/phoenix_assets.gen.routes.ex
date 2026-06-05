defmodule Mix.Tasks.PhoenixAssets.Gen.Routes do
  @moduledoc "Generates only the routes contract. See `mix help phoenix_assets.gen`."
  @shortdoc "Generate the routes contract"

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Mix.Task.run("phoenix_assets.gen", ["--only", "routes" | args])
end

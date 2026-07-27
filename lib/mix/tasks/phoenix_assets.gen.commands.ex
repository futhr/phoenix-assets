defmodule Mix.Tasks.PhoenixAssets.Gen.Commands do
  @moduledoc "Generates only the command (mutation) contract. See `mix help phoenix_assets.gen`."
  @shortdoc "Generate the commands contract"

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Mix.Task.run("phoenix_assets.gen", ["--only", "commands" | args])
end

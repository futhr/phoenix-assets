defmodule Mix.Tasks.PhoenixAssets.Gen.Session do
  @moduledoc "Generates only the session (context) contract. See `mix help phoenix_assets.gen`."
  @shortdoc "Generate the session contract"

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Mix.Task.run("phoenix_assets.gen", ["--only", "session" | args])
end

defmodule Mix.Tasks.PhoenixAssets.Graph do
  @moduledoc """
  Builds the Phoenix Asset Graph and writes it to `graph.json`.

  Run after the Vite production build so the graph can merge the manifest's entry
  chunks with the plugin-contributed pages, routes, shapes, topics, and locales.
  """
  @shortdoc "Build the Phoenix Asset Graph"

  use Mix.Task

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_) do
    ctx = PhoenixAssets.MixHelpers.context!(env: Mix.env())
    {:ok, path} = PhoenixAssets.Graph.write(ctx)
    Mix.shell().info("phoenix_assets: wrote asset graph to #{path}")
  end
end

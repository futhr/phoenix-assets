defmodule PhoenixAssets.Storybook do
  @moduledoc """
  Integration plugin that supervises Storybook alongside the app.

  Storybook shares the app's Vite config, so it depends on the SvelteKit
  integration and is ordered after Tailwind. Contributing it as a supervised dev
  process is the fix for the common gap where Storybook is started by hand and
  drifts from the app -- now `mix phx.server` brings it up and tears it down with
  everything else.

  ## Why

  A component workshop that isn't part of the supervised dev lifecycle gets
  forgotten, runs stale, or leaks its port. Making it a real child closes that gap.
  """

  use PhoenixAssets.Plugin

  depends_on(PhoenixAssets.SvelteKit)
  after_plugin(PhoenixAssets.Tailwind)

  alias PhoenixAssets.DevProcess

  @default_port 6006

  @impl PhoenixAssets.Plugin
  def init(opts, _), do: {:ok, Map.new(opts)}

  @impl PhoenixAssets.Plugin
  def dev_processes(ctx, state) do
    if Map.get(state, :enabled, true) do
      port = Map.get(state, :port, @default_port)

      [
        DevProcess.new(
          id: :storybook,
          command: ["pnpm", "storybook", "dev", "-p", to_string(port)],
          cd: ctx.asset_root,
          port: port
        )
      ]
    else
      []
    end
  end
end

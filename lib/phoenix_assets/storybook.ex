defmodule PhoenixAssets.Storybook do
  @moduledoc """
  Integration plugin that supervises Storybook alongside the app.

  Storybook shares the app's Vite config, so it depends on the SvelteKit
  integration and is ordered after Tailwind. Contributing it as a supervised dev
  process is the fix for the common gap where Storybook is started by hand and
  drifts from the app -- now `mix phx.server` brings it up and tears it down with
  everything else.

  Configure (or disable) it without writing a preset:

      config :phoenix_assets, :dev,
        storybook: [enabled: false]          # or: [port: 6007, command: [...]]

  Preset `integration/2` options provide the defaults; the `:dev` config wins.

  """

  use PhoenixAssets.Plugin

  depends_on(PhoenixAssets.SvelteKit)
  after_plugin(PhoenixAssets.Tailwind)

  alias PhoenixAssets.{Context, DevProcess}

  @default_port 6006

  @impl PhoenixAssets.Plugin
  def init(opts, _), do: {:ok, Map.new(opts)}

  @impl PhoenixAssets.Plugin
  def dev_processes(ctx, state) do
    opts = storybook_opts(ctx, state)

    if Keyword.get(opts, :enabled, true) do
      port = Keyword.get(opts, :port, @default_port)

      [
        DevProcess.new(
          id: :storybook,
          command: Keyword.get(opts, :command, default_command(ctx, port)),
          cd: ctx.asset_root,
          port: port
        )
      ]
    else
      []
    end
  end

  # Host config (`config :phoenix_assets, :dev, storybook: [...]`) overrides
  # preset opts, mirroring how the SvelteKit plugin reads `dev: [vite: [...]]`.
  defp storybook_opts(ctx, state) do
    Keyword.merge(Map.to_list(state), ctx.config.dev[:storybook] || [])
  end

  # Exec the Storybook binary directly (see `Context.bin_path/2` -- a
  # package-manager wrapper would orphan the node child under MuonTrap and
  # leak the port). `--no-open` keeps a supervised restart from popping a
  # browser window.
  defp default_command(ctx, port) do
    [Context.bin_path(ctx, "storybook"), "dev", "-p", to_string(port), "--no-open"]
  end
end

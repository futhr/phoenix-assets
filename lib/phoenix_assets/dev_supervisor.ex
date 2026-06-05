defmodule PhoenixAssets.DevSupervisor do
  @moduledoc """
  Supervises the development asset processes for a host application.

  Starts the dev-process tracker (`PhoenixAssets.DevServer`), the
  generated-contracts watcher (`PhoenixAssets.Generated.Watcher`), and one
  `MuonTrap.Daemon` per enabled `PhoenixAssets.DevProcess` contributed by the
  plugins (Vite, Storybook). The daemons inherit guaranteed teardown from
  MuonTrap: `Ctrl+C` on `mix phx.server` stops Phoenix, which stops this
  supervisor, which stops every daemon's OS process group and frees its port.

  Started only in development -- `PhoenixAssets.child_specs/1` includes it only
  when `PhoenixAssets.dev?/0` is true.

  ## Why

  "No shell script should be required to kill Vite." Making the dev processes
  real supervised children means their lifecycle is the BEAM's lifecycle, with no
  orphans and no leaked ports.
  """

  use Supervisor

  require Logger

  alias PhoenixAssets.{Context, DevProcess, DevServer, Engine}
  alias PhoenixAssets.Generated.Watcher

  @default_watch_dirs ["lib", "priv/gettext"]

  @doc """
  Starts the dev supervisor.

  Options:

    * `:ctx` (required) -- the `PhoenixAssets.Context`.
    * `:watch_dirs` -- directories the generated-file watcher observes
      (default `["lib", "priv/gettext"]`).
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(opts) do
    ctx = Keyword.fetch!(opts, :ctx)
    watch_dirs = Keyword.get(opts, :watch_dirs, @default_watch_dirs)

    children =
      [DevServer, Watcher.child_spec_for(ctx, dirs: watch_dirs)] ++ daemons(ctx)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp daemons(%Context{} = ctx) do
    ctx
    |> dev_processes()
    |> Enum.filter(& &1.enabled)
    |> Enum.map(fn process ->
      DevProcess.to_child_spec(process, logger_fun: {DevServer, :log_line, [process.id]})
    end)
  end

  defp dev_processes(ctx) do
    case Engine.init_plugins(ctx) do
      {:ok, initialized} ->
        Engine.collect(ctx, initialized, :dev_processes)

      {:error, {module, reason}} ->
        Logger.error(
          "phoenix_assets: dev processes not started — plugin #{inspect(module)} " <>
            "failed to initialise: #{inspect(reason)}"
        )

        []
    end
  end
end

defmodule PhoenixAssets.DevSupervisor do
  @moduledoc """
  Supervises the development asset processes for a host application.

  Starts the dev-process tracker (`PhoenixAssets.DevServer`), the
  generated-contracts watcher (`PhoenixAssets.Generated.Watcher`), and one
  `MuonTrap.Daemon` per enabled `PhoenixAssets.DevProcess` contributed by the
  plugins (Vite, Storybook). Stopping the supervisor (`Ctrl+C` on
  `mix phx.server` stops Phoenix, which stops this supervisor) stops each
  daemon and frees its port. Full OS process-tree teardown is only guaranteed
  where MuonTrap can use Linux cgroups; on macOS (and other systems without
  cgroups) MuonTrap kills the immediate child, so a grandchild that ignores its
  parent's exit can still escape.

  The daemons restart `:transient` under a deliberately generous restart
  intensity so a transiently failing process (e.g. Vite exiting nonzero on a
  busy port) is retried rather than exhausting the supervisor and tearing the
  failure into the host application's tree.

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

  # Generous relative to the OTP default of 3 restarts / 5s: a daemon exiting
  # nonzero on a busy port should be retried, not crash `mix phx.server`.
  @max_restarts 10
  @max_seconds 5

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

    Supervisor.init(children,
      strategy: :one_for_one,
      max_restarts: @max_restarts,
      max_seconds: @max_seconds
    )
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

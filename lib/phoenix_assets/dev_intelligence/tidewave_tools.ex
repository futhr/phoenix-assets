defmodule PhoenixAssets.DevIntelligence.TidewaveTools do
  @moduledoc """
  Runtime introspection helpers for the asset pipeline, callable from Tidewave.

  Surfaces the dev-process state, recent logs, restart control, and a doctor run
  through plain functions an agent or developer can invoke at runtime. This is the
  one dev-intelligence integration the stack ships; the broader overlay, Tower,
  and BeamLens bridges are intentionally out of scope until a host needs them.

  """

  alias PhoenixAssets.{Config, Context, DevServer, Doctor}

  @infra_children [PhoenixAssets.DevServer, PhoenixAssets.Generated.Watcher]

  @doc """
  A snapshot of each supervised dev process's status, keyed by process id.

  Enumerates whatever the dev supervisor actually runs (so custom presets and
  disabled processes are reflected), excluding the supervisor's own
  infrastructure children. Empty when the dev supervisor is not running.
  """
  @spec status() :: %{atom() => :running | :restarting | :down | :unknown}
  def status do
    Map.new(daemon_ids(), fn id -> {id, DevServer.status(id)} end)
  end

  defp daemon_ids do
    PhoenixAssets.DevSupervisor
    |> Supervisor.which_children()
    |> Enum.map(fn {id, _, _, _} -> id end)
    |> Enum.reject(&(&1 in @infra_children))
  catch
    :exit, _ -> []
  end

  @doc "Recent output lines for a dev process (`:vite` or `:storybook`)."
  @spec logs(atom(), keyword()) :: [String.t()]
  def logs(id, opts \\ []), do: DevServer.logs(id, opts)

  @doc "Restarts a supervised dev process."
  @spec restart(atom()) :: {:ok, pid()} | {:error, term()}
  def restart(id), do: DevServer.restart(id)

  @doc "Runs the asset-pipeline doctor against the configured preset."
  @spec doctor(keyword()) :: {Doctor.Check.status(), [{Doctor.Check.t(), Doctor.Check.result()}]}
  def doctor(opts \\ []) do
    config = Config.load!()
    ctx = Context.new(config, plugins: Config.preset_plugins(config), env: :dev)
    Doctor.run(ctx, opts)
  end
end

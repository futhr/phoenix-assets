defmodule PhoenixAssets.DevProcess do
  @moduledoc """
  A declaration of an external development process to supervise (Vite, Storybook).

  Plugins return these from `c:PhoenixAssets.Plugin.dev_processes/2`. The dev
  supervisor turns each declaration into a supervised child that MuonTrap tears
  down when the BEAM stops. Where MuonTrap can use Linux cgroups the whole OS
  process tree goes with it; on macOS (and other systems without cgroups) only
  the immediate child is killed, so a stubborn grandchild can still leak. The
  child-spec construction (`to_child_spec/2`) lives alongside the dev
  supervisor.

  ## Why

  Describing a dev process as data keeps the plugin layer free of supervision
  concerns: a plugin says *what* to run; the dev supervisor decides *how* to run
  and tear it down.
  """

  @type t :: %__MODULE__{
          id: atom(),
          command: [String.t()],
          cd: Path.t(),
          env: [{String.t(), String.t()}],
          port: pos_integer() | nil,
          enabled: boolean(),
          restart: :transient | :permanent | :temporary
        }

  @enforce_keys [:id, :command, :cd]
  defstruct [:id, :command, :cd, :port, env: [], enabled: true, restart: :transient]

  @doc "Builds a dev-process declaration from a keyword list or map of attributes."
  @spec new(Enumerable.t()) :: t()
  def new(attrs), do: struct!(__MODULE__, attrs)

  alias PhoenixAssets.{DevServer, Telemetry}

  @doc """
  Builds a supervised `MuonTrap.Daemon` child spec for this dev process.

  MuonTrap wraps the OS process and kills it when the BEAM exits -- even on a
  hard crash -- releasing the port (the whole process tree where Linux cgroups
  are available, otherwise the immediate child). `stderr_to_stdout: true` folds
  the process's stderr into stdout so Vite/Storybook errors reach the log
  buffer. `:logger_fun` (an `mfargs` tuple) routes that output to the dev
  server's log buffer. Each start emits `[:phoenix_assets, :dev_server, :start]`,
  and the dev server monitors the daemon to emit `:stop`/`:crash` on exit.
  """
  @spec to_child_spec(t(), keyword()) :: Supervisor.child_spec()
  def to_child_spec(%__MODULE__{} = process, opts \\ []) do
    [command | args] = process.command

    daemon_opts =
      [
        cd: process.cd,
        env: process.env,
        stderr_to_stdout: true,
        exit_status_to_reason: &{:exit_status, &1}
      ]
      |> put_logger_fun(opts[:logger_fun])

    %{
      id: process.id,
      start: {__MODULE__, :start_daemon, [process.id, command, args, daemon_opts]},
      restart: process.restart,
      shutdown: 500,
      type: :worker
    }
  end

  @doc false
  @spec start_daemon(atom(), String.t(), [String.t()], keyword()) :: GenServer.on_start()
  def start_daemon(id, command, args, daemon_opts) do
    with {:ok, pid} <- MuonTrap.Daemon.start_link(command, args, daemon_opts) do
      Telemetry.execute([:dev_server, :start], %{}, %{id: id, os_pid: os_pid(pid)})
      DevServer.monitor_daemon(id, pid)
      {:ok, pid}
    end
  end

  defp os_pid(pid) do
    MuonTrap.Daemon.os_pid(pid)
  catch
    # The daemon may have exited between start_link/3 returning and this call,
    # which surfaces as an exit from the GenServer.call inside os_pid/1. That is
    # the only expected failure; let anything else surface rather than masking it.
    :exit, _ -> nil
  end

  defp put_logger_fun(opts, nil), do: opts
  defp put_logger_fun(opts, fun), do: Keyword.put(opts, :logger_fun, fun)
end

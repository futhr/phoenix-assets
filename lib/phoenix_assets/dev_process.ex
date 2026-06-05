defmodule PhoenixAssets.DevProcess do
  @moduledoc """
  A declaration of an external development process to supervise (Vite, Storybook).

  Plugins return these from `c:PhoenixAssets.Plugin.dev_processes/2`. The dev
  supervisor turns each declaration into a supervised child whose entire OS
  process tree is torn down when the BEAM stops -- no orphaned Vite, no leaked
  ports. The child-spec construction (`to_child_spec/2`) lives alongside the dev
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

  @doc """
  Builds a supervised `MuonTrap.Daemon` child spec for this dev process.

  MuonTrap wraps the OS process so its entire process group is torn down when the
  BEAM exits -- even on a hard crash -- releasing the port. `:logger_fun` (an
  `mfargs` tuple) routes the process's output to the dev server's log buffer.
  """
  @spec to_child_spec(t(), keyword()) :: Supervisor.child_spec()
  def to_child_spec(%__MODULE__{} = process, opts \\ []) do
    [command | args] = process.command

    daemon_opts =
      [cd: process.cd, env: process.env, exit_status_to_reason: &{:exit_status, &1}]
      |> put_logger_fun(opts[:logger_fun])

    %{
      id: process.id,
      start: {MuonTrap.Daemon, :start_link, [command, args, daemon_opts]},
      restart: process.restart,
      shutdown: 500,
      type: :worker
    }
  end

  defp put_logger_fun(opts, nil), do: opts
  defp put_logger_fun(opts, fun), do: Keyword.put(opts, :logger_fun, fun)
end

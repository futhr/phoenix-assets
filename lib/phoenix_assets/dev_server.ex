defmodule PhoenixAssets.DevServer do
  @moduledoc """
  Tracks supervised dev processes and buffers their output.

  Provides the operator surface over the dev processes the `DevSupervisor`
  runs: query liveness (`status/1`), restart or stop a process, and read a
  recent slice of its output (`logs/2`). Each `MuonTrap.Daemon` is configured to
  route its output here via `log_line/2`, where it is kept in a small per-process
  ring buffer.

  ## Why

  When Vite or Storybook is supervised by Phoenix, developers (and Tidewave) need
  the same conveniences a terminal gave them: is it up, restart it, show me the
  last lines. This module is that surface.
  """

  use GenServer

  @ring_size 200
  @supervisor PhoenixAssets.DevSupervisor
  @infra_children [__MODULE__, PhoenixAssets.Generated.Watcher]

  @doc "Starts the dev-process tracker."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Liveness of the dev process with the given id."
  @spec status(atom()) :: :running | :restarting | :down | :unknown
  def status(id) do
    @supervisor
    |> Supervisor.which_children()
    |> Enum.find(fn {child_id, _, _, _} -> child_id == id end)
    |> child_status()
  catch
    :exit, _ -> :unknown
  end

  @doc """
  Restarts the dev process with the given id.

  Returns `{:error, :not_running}` when the dev supervisor itself is down
  (production, or dev mode disabled) -- this surface is called from Tidewave
  and must degrade instead of crashing the caller.
  """
  @spec restart(atom()) :: {:ok, pid()} | {:error, term()}
  def restart(id) do
    _ = Supervisor.terminate_child(@supervisor, id)

    case Supervisor.restart_child(@supervisor, id) do
      {:ok, pid} -> {:ok, pid}
      {:ok, pid, _} -> {:ok, pid}
      error -> error
    end
  catch
    :exit, _ -> {:error, :not_running}
  end

  @doc """
  Stops the dev process with the given id.

  Returns `{:error, :not_running}` when the dev supervisor itself is down.
  """
  @spec stop(atom()) :: :ok | {:error, term()}
  def stop(id) do
    Supervisor.terminate_child(@supervisor, id)
  catch
    :exit, _ -> {:error, :not_running}
  end

  @doc """
  Returns the most recent output lines for `id` (oldest first).

  Returns `[]` when the tracker is not running.
  """
  @spec logs(atom(), keyword()) :: [String.t()]
  def logs(id, opts \\ []) do
    GenServer.call(__MODULE__, {:logs, id, Keyword.get(opts, :limit, 50)})
  catch
    :exit, _ -> []
  end

  @doc "Appends an output `line` for dev process `id`. A no-op if the server is down."
  @spec log_line(String.t(), atom()) :: :ok
  def log_line(line, id), do: GenServer.cast(__MODULE__, {:log, id, line})

  @doc """
  Monitors a daemon so `[:phoenix_assets, :dev_server, :stop | :crash]` is
  emitted when it exits. A no-op if the tracker is down.
  """
  @spec monitor_daemon(atom(), pid()) :: :ok
  def monitor_daemon(id, pid), do: GenServer.cast(__MODULE__, {:monitor, id, pid})

  @impl GenServer
  def init(_) do
    {:ok, %{logs: %{}, monitors: %{}}, {:continue, :establish_monitors}}
  end

  # Daemons left running by `one_for_one` when this tracker restarts would
  # otherwise never emit `:stop`/`:crash` again -- re-establish their monitors
  # from whatever the dev supervisor currently runs.
  @impl GenServer
  def handle_continue(:establish_monitors, state) do
    monitors =
      @supervisor
      |> Supervisor.which_children()
      |> Enum.reduce(state.monitors, fn
        {id, pid, _, _}, acc when is_pid(pid) and id not in @infra_children ->
          put_monitor(acc, id, pid)

        _, acc ->
          acc
      end)

    {:noreply, %{state | monitors: monitors}}
  catch
    :exit, _ -> {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:log, id, line}, state) do
    logs = Map.update(state.logs, id, push(new_ring(), line), &push(&1, line))
    {:noreply, %{state | logs: logs}}
  end

  def handle_cast({:monitor, id, pid}, state) do
    {:noreply, %{state | monitors: put_monitor(state.monitors, id, pid)}}
  end

  @impl GenServer
  def handle_call({:logs, id, limit}, _, state) do
    lines = state.logs |> Map.get(id, new_ring()) |> ring_to_list() |> Enum.take(-limit)
    {:reply, lines, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, pid, reason}, state) do
    {id, monitors} = Map.pop(state.monitors, pid)

    if id do
      PhoenixAssets.Telemetry.execute([:dev_server, event_for(reason)], %{}, %{
        id: id,
        reason: reason
      })
    end

    {:noreply, %{state | monitors: monitors}}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Monitors are keyed by pid so a re-scan never double-monitors a daemon the
  # cast path already registered.
  defp put_monitor(monitors, id, pid) do
    if Map.has_key?(monitors, pid) do
      monitors
    else
      Process.monitor(pid)
      Map.put(monitors, pid, id)
    end
  end

  # A bounded ring buffer as `{count, :queue}`: pushing is O(1) amortised, so a
  # busy process's output never rebuilds the whole buffer per line.
  defp new_ring, do: {0, :queue.new()}

  defp push({count, queue}, line) when count >= @ring_size do
    {_, queue} = :queue.out(queue)
    {count, :queue.in(line, queue)}
  end

  defp push({count, queue}, line), do: {count + 1, :queue.in(line, queue)}

  defp ring_to_list({_, queue}), do: :queue.to_list(queue)

  defp event_for(reason) when reason in [:normal, :shutdown], do: :stop
  defp event_for({:shutdown, _}), do: :stop
  defp event_for(_), do: :crash

  defp child_status(nil), do: :unknown
  defp child_status({_, pid, _, _}) when is_pid(pid), do: :running
  defp child_status({_, :restarting, _, _}), do: :restarting
  defp child_status({_, :undefined, _, _}), do: :down
  defp child_status(_), do: :unknown
end

defmodule PhoenixAssets.Generated.Watcher do
  @moduledoc """
  Regenerates frontend contracts when backend source changes, in development.

  Subscribes (via `:file_system`) to the host application's Elixir source and
  gettext directories. On a change it debounces briefly and then runs
  `PhoenixAssets.Generated.generate/1`. Because generation is content-gated, a
  change that does not affect any contract performs no write and triggers no Vite
  HMR; a change that does updates exactly the affected files, which Vite then hot
  reloads.

  The watcher never watches the generated-output directory (it lives under the
  asset root, not under `lib/`), so it can never trigger itself -- there is no
  feedback loop.

  ## Why

  Editing an Ash resource or a router entry should update the TypeScript the
  frontend sees, with the same immediacy as editing a Svelte file. This watcher
  is the Phoenix-side half of that loop; Vite owns the frontend half.
  """

  use GenServer

  require Logger

  alias PhoenixAssets.{Context, Generated}

  @default_dirs ["lib", "priv/gettext"]
  @default_debounce_ms 150

  @doc """
  Starts the watcher.

  Options:

    * `:ctx` (required) -- the `PhoenixAssets.Context` to regenerate from.
    * `:dirs` -- directories to watch (default `["lib", "priv/gettext"]`,
      filtered to those that exist).
    * `:debounce_ms` -- coalescing window in milliseconds (default `150`).
    * `:name` -- the registered name (default the module).
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    ctx = Keyword.fetch!(opts, :ctx)
    debounce = Keyword.get(opts, :debounce_ms, @default_debounce_ms)
    dirs = opts |> Keyword.get(:dirs, @default_dirs) |> Enum.filter(&File.dir?/1)

    state = %{ctx: ctx, debounce: debounce, timer: nil, watcher: nil}

    case start_file_system(dirs) do
      {:ok, watcher} -> {:ok, %{state | watcher: watcher}}
      :none -> {:ok, state}
    end
  end

  @impl GenServer
  def handle_info({:file_event, _, {_, _}}, state) do
    {:noreply, schedule(state)}
  end

  def handle_info({:file_event, _, :stop}, state) do
    {:noreply, state}
  end

  def handle_info(:regenerate, %{ctx: ctx} = state) do
    case Generated.generate(ctx) do
      {:ok, %{written: [_ | _] = written}} ->
        Logger.debug("phoenix_assets regenerated: #{Enum.join(written, ", ")}")

      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("phoenix_assets generation failed: #{inspect(reason)}")
    end

    {:noreply, %{state | timer: nil}}
  end

  def handle_info(message, state) do
    Logger.debug("phoenix_assets watcher: ignoring unexpected message #{inspect(message)}")
    {:noreply, state}
  end

  defp schedule(%{timer: timer, debounce: debounce} = state) do
    _ = if is_reference(timer), do: Process.cancel_timer(timer)
    %{state | timer: Process.send_after(self(), :regenerate, debounce)}
  end

  defp start_file_system([]), do: :none

  defp start_file_system(dirs) do
    case FileSystem.start_link(dirs: dirs) do
      {:ok, watcher} ->
        FileSystem.subscribe(watcher)
        {:ok, watcher}

      _ ->
        :none
    end
  end

  @doc false
  @spec child_spec_for(Context.t(), keyword()) :: Supervisor.child_spec()
  def child_spec_for(%Context{} = ctx, opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [Keyword.put(opts, :ctx, ctx)]}
    }
  end
end

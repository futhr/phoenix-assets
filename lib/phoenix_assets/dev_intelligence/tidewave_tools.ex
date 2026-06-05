defmodule PhoenixAssets.DevIntelligence.TidewaveTools do
  @moduledoc """
  Runtime introspection helpers for the asset pipeline, callable from Tidewave.

  Surfaces the dev-process state, recent logs, restart control, and a doctor run
  through plain functions an agent or developer can invoke at runtime. This is the
  one dev-intelligence integration the stack ships; the broader overlay, Tower,
  and BeamLens bridges are intentionally out of scope until a host needs them.

  ## Why

  When Vite and Storybook are supervised by Phoenix, the natural question is
  "what's their state, and can I poke them?" -- exposing that as callable
  functions makes the supervised processes inspectable from the same runtime tools
  used for the rest of the app.
  """

  alias PhoenixAssets.{Config, Context, DevServer, Doctor}

  @doc "A snapshot of each supervised dev process's status."
  @spec status() :: %{vite: atom(), storybook: atom()}
  def status do
    %{vite: DevServer.status(:vite), storybook: DevServer.status(:storybook)}
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
    ctx = Context.new(config, plugins: Config.preset_plugins(config))
    Doctor.run(ctx, opts)
  end
end

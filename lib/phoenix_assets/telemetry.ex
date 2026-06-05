defmodule PhoenixAssets.Telemetry do
  @moduledoc """
  Telemetry instrumentation for `phoenix_assets`.

  All events are prefixed with `:phoenix_assets`. Long-running operations use
  `:telemetry.span/3`, which emits `:start`, `:stop`, and `:exception` events
  carrying timing measurements and the metadata passed in.

  ## Events

    * `[:phoenix_assets, :generated, :start | :stop | :exception]` -- a contract
      generation run. Metadata: `%{otp_app:, files:, written:}`.
    * `[:phoenix_assets, :generated, :stale]` -- a `--check` run found drift.
      Metadata: `%{otp_app:, stale: [Path.t()]}`.
    * `[:phoenix_assets, :manifest, :load]` -- a Vite manifest was parsed.
    * `[:phoenix_assets, :manifest, :missing_entry]` -- an entry was requested
      but absent from the manifest. Metadata: `%{entry:}`.
    * `[:phoenix_assets, :dev_server, :start | :stop | :crash]` -- a supervised
      dev process changed state. Metadata: `%{id:, os_pid:}`.
    * `[:phoenix_assets, :doctor, :run]` -- a doctor run finished. Metadata:
      `%{status:, checks:}`.

  ## Why

  The dev-intelligence layer and host observability stacks need a stable event
  surface to attach to. Centralising the prefix and the span/execute wrappers
  keeps event names consistent across the library.
  """

  @prefix :phoenix_assets

  @doc """
  Runs `fun` inside a telemetry span under `[:phoenix_assets | suffix]`.

  `fun` must return `{result, extra_metadata}`; `result` is returned to the
  caller and `extra_metadata` is merged into the `:stop` event metadata.
  """
  @spec span([atom()], :telemetry.event_metadata(), (-> {result, :telemetry.event_metadata()})) ::
          result
        when result: var
  def span(suffix, metadata, fun) when is_list(suffix) and is_function(fun, 0) do
    :telemetry.span([@prefix | suffix], metadata, fun)
  end

  @doc "Emits a one-off telemetry event under `[:phoenix_assets | suffix]`."
  @spec execute([atom()], :telemetry.event_measurements(), :telemetry.event_metadata()) :: :ok
  def execute(suffix, measurements, metadata) when is_list(suffix) do
    :telemetry.execute([@prefix | suffix], measurements, metadata)
  end
end

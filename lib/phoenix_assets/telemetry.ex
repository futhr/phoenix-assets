defmodule PhoenixAssets.Telemetry do
  @moduledoc """
  Telemetry instrumentation for `phoenix_assets`.

  All events are prefixed with `:phoenix_assets`. Long-running operations use
  `:telemetry.span/3`, which emits `:start`, `:stop`, and `:exception` events
  carrying timing measurements and the metadata passed in.

  ## Events

    * `[:phoenix_assets, :generated, :start | :stop | :exception]` -- a contract
      generation run (span). Start metadata: `%{otp_app:, check:}`; the stop
      event adds `%{written:, unchanged:}` (write runs) or `%{stale:}` (check
      runs).
    * `[:phoenix_assets, :generated, :stale]` -- a check run found drift.
      Measurements: `%{stale: count}`. Metadata: `%{otp_app:, stale: [Path.t()]}`.
    * `[:phoenix_assets, :manifest, :load]` -- a Vite manifest was parsed.
      Measurements: `%{entries: count}`. Metadata: `%{path:}`.
    * `[:phoenix_assets, :manifest, :missing_entry]` -- an entry was requested
      but absent from the manifest. Metadata: `%{entry:}`.
    * `[:phoenix_assets, :dev_server, :start]` -- a supervised dev process
      started. Metadata: `%{id:, os_pid:}`.
    * `[:phoenix_assets, :dev_server, :stop | :crash]` -- a supervised dev
      process exited (cleanly or not). Metadata: `%{id:, reason:}`.
    * `[:phoenix_assets, :doctor, :run]` -- a doctor run finished.
      Measurements: `%{checks: count}`. Metadata: `%{status:}`.
    * `[:phoenix_assets, :graph, :degraded]` -- the asset graph was assembled with
      missing data. Metadata: `%{reason: :plugin_init_failed, plugin:, error:}` (a
      plugin's `init/2` failed) or `%{reason: :manifest_unreadable, path:, error:}`
      (the Vite manifest existed but could not be read or parsed).

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

  @doc """
  Emits a one-off telemetry event under `[:phoenix_assets | suffix]`.

  A `:system_time` measurement (`System.system_time/0`) is always added so
  handlers can timestamp a point event without relying on their own clock, per
  the `:telemetry` convention for non-span events.
  """
  @spec execute([atom()], :telemetry.event_measurements(), :telemetry.event_metadata()) :: :ok
  def execute(suffix, measurements, metadata) when is_list(suffix) do
    measurements = Map.put(measurements, :system_time, System.system_time())
    :telemetry.execute([@prefix | suffix], measurements, metadata)
  end
end

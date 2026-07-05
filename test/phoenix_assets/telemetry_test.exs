defmodule PhoenixAssets.TelemetryTest do
  @moduledoc false

  # Telemetry handlers are global; each test attaches a unique handler id and
  # detaches on exit, but runs sync to avoid cross-test event bleed.
  use ExUnit.Case, async: false

  alias PhoenixAssets.{Config, Context, DevProcess, DevServer, Doctor, Generated, GeneratedFile}
  alias PhoenixAssets.Manifest

  defmodule StalePlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def generated_files(_, _) do
      [GeneratedFile.new(path: "gen/x.ts", contents: "x\n", plugin: :x, kind: :x)]
    end
  end

  defmodule RaisingPlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def generated_files(_, _), do: raise("boom in generated_files")
  end

  defp tmp_ctx(plugins) do
    tmp = Path.join(System.tmp_dir!(), "tg_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    Context.new(Config.load!(otp_app: :my_app, asset_root: tmp), env: :test, plugins: plugins)
  end

  defp attach(events) do
    parent = self()
    id = "telemetry-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      id,
      events,
      fn event, measurements, metadata, _ ->
        send(parent, {:event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(id) end)
  end

  test "[:manifest, :load] fires when a manifest parses" do
    attach([[:phoenix_assets, :manifest, :load]])

    path = Path.join(System.tmp_dir!(), "tm_#{System.unique_integer([:positive])}.json")
    File.write!(path, ~s({"src/app.ts":{"file":"a.js"}}))
    on_exit(fn -> File.rm_rf!(path) end)

    assert {:ok, _} = Manifest.load(path)
    assert_received {:event, [:phoenix_assets, :manifest, :load], %{entries: 1}, %{path: ^path}}
  end

  test "[:manifest, :missing_entry] fires before the KeyError" do
    attach([[:phoenix_assets, :manifest, :missing_entry]])

    assert_raise KeyError, fn -> Manifest.entry!(%{}, "ghost") end
    assert_received {:event, [:phoenix_assets, :manifest, :missing_entry], _, %{entry: "ghost"}}
  end

  test "[:generated, :stale] fires when a check run finds drift" do
    attach([[:phoenix_assets, :generated, :stale]])

    tmp = Path.join(System.tmp_dir!(), "ts_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    ctx =
      Context.new(Config.load!(otp_app: :my_app, asset_root: tmp),
        env: :test,
        plugins: [{StalePlugin, []}]
      )

    assert {:error, {:stale, ["gen/x.ts"]}} = Generated.generate(ctx, check: true)

    assert_received {:event, [:phoenix_assets, :generated, :stale], %{stale: 1},
                     %{otp_app: :my_app, stale: ["gen/x.ts"]}}
  end

  test "[:dev_server, :start] and [:dev_server, :stop] fire across a daemon's life" do
    attach([
      [:phoenix_assets, :dev_server, :start],
      [:phoenix_assets, :dev_server, :stop]
    ])

    start_supervised!(DevServer)

    assert {:ok, pid} = DevProcess.start_daemon(:probe, "sleep", ["5"], [])
    assert_received {:event, [:phoenix_assets, :dev_server, :start], _, %{id: :probe} = meta}
    assert is_integer(meta.os_pid)

    # A call flushes the async :monitor cast, guaranteeing the monitor exists
    # before the daemon dies (otherwise DOWN arrives as :noproc).
    _ = DevServer.logs(:probe)

    # Unlink so stopping the daemon does not take the test process down.
    Process.unlink(pid)
    GenServer.stop(pid, :shutdown)

    assert_receive {:event, [:phoenix_assets, :dev_server, :stop], _,
                    %{id: :probe, reason: :shutdown}},
                   1_000
  end

  test "[:dev_server, :crash] fires when a daemon exits with a non-shutdown reason" do
    attach([[:phoenix_assets, :dev_server, :crash]])

    start_supervised!(DevServer)

    assert {:ok, pid} = DevProcess.start_daemon(:crasher, "sleep", ["5"], [])
    # Flush the async :monitor cast so the monitor is in place before the exit.
    _ = DevServer.logs(:crasher)

    # Unlink so the abnormal exit does not take the test process down with it.
    Process.unlink(pid)
    GenServer.stop(pid, :boom)

    assert_receive {:event, [:phoenix_assets, :dev_server, :crash], _,
                    %{id: :crasher, reason: :boom}},
                   1_000
  end

  test "[:doctor, :run] fires once a doctor run finishes, carrying the check count and status" do
    attach([[:phoenix_assets, :doctor, :run]])

    {status, results} = Doctor.run(tmp_ctx([]))

    assert_received {:event, [:phoenix_assets, :doctor, :run], %{checks: checks},
                     %{status: ^status}}

    assert checks == length(results)
    assert checks > 0
    assert status in [:ok, :error]
  end

  test "[:generated, :start | :stop] wrap a write run as a span" do
    attach([
      [:phoenix_assets, :generated, :start],
      [:phoenix_assets, :generated, :stop]
    ])

    ctx = tmp_ctx([{StalePlugin, []}])

    assert {:ok, %{written: ["gen/x.ts"], unchanged: []}} = Generated.generate(ctx)

    assert_received {:event, [:phoenix_assets, :generated, :start], _,
                     %{otp_app: :my_app, check: false}}

    assert_received {:event, [:phoenix_assets, :generated, :stop], %{duration: _},
                     %{otp_app: :my_app, check: false, written: 1, unchanged: 0}}
  end

  test "[:generated, :exception] fires when a plugin raises mid-generation" do
    attach([[:phoenix_assets, :generated, :exception]])

    ctx = tmp_ctx([{RaisingPlugin, []}])

    assert_raise RuntimeError, ~r/boom in generated_files/, fn -> Generated.generate(ctx) end

    assert_received {:event, [:phoenix_assets, :generated, :exception], %{duration: _}, meta}
    assert meta.kind == :error
    assert meta.otp_app == :my_app
  end
end

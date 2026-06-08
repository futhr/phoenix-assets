defmodule PhoenixAssets.Generated.WatcherTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias PhoenixAssets.{Config, Context, GeneratedFile}
  alias PhoenixAssets.Generated.Watcher

  defmodule WritePlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def generated_files(_, _) do
      [
        GeneratedFile.new(
          path: "phoenix/probe.ts",
          contents: "export const probe = 1\n",
          plugin: :probe,
          kind: :probe
        )
      ]
    end
  end

  defmodule FailPlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def init(_, _), do: {:error, :boom}
  end

  defp state do
    ctx = Context.new(Config.load!(otp_app: :my_app), env: :test, plugins: [])
    %{ctx: ctx, debounce: 5, timer: nil, watcher: nil}
  end

  defp tmp_dir do
    dir = Path.join(System.tmp_dir!(), "w_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  test "a file event schedules a debounced regeneration" do
    assert {:noreply, new_state} =
             Watcher.handle_info({:file_event, self(), {"lib/x.ex", [:modified]}}, state())

    assert is_reference(new_state.timer)
  end

  test "a second event reschedules with a fresh timer" do
    {:noreply, s1} = Watcher.handle_info({:file_event, self(), {"a", [:modified]}}, state())
    {:noreply, s2} = Watcher.handle_info({:file_event, self(), {"b", [:modified]}}, s1)

    assert is_reference(s2.timer)
    refute s1.timer == s2.timer
  end

  test ":regenerate runs generation and clears the timer" do
    assert {:noreply, %{timer: nil}} =
             Watcher.handle_info(:regenerate, %{state() | timer: make_ref()})
  end

  test ":stop is ignored" do
    s = state()
    assert {:noreply, ^s} = Watcher.handle_info({:file_event, self(), :stop}, s)
  end

  test "an unexpected message is ignored without crashing" do
    s = state()
    assert {:noreply, ^s} = Watcher.handle_info(:unexpected, s)
  end

  test "subscribes to a file-system watcher for an existing directory" do
    ctx = Context.new(Config.load!(otp_app: :my_app), env: :test, plugins: [])
    pid = start_supervised!({Watcher, ctx: ctx, dirs: [tmp_dir()], name: :fs_watcher})

    assert is_pid(:sys.get_state(pid).watcher)
  end

  test ":regenerate logs the written contracts when generation writes files" do
    ctx =
      Context.new(Config.load!(otp_app: :my_app, asset_root: tmp_dir()),
        env: :test,
        plugins: [{WritePlugin, []}]
      )

    log =
      capture_log(fn ->
        assert {:noreply, %{timer: nil}} =
                 Watcher.handle_info(:regenerate, %{ctx: ctx, debounce: 5, timer: make_ref()})
      end)

    assert log =~ "regenerated"
    assert log =~ "phoenix/probe.ts"
  end

  test ":regenerate logs a warning when generation fails" do
    ctx =
      Context.new(Config.load!(otp_app: :my_app), env: :test, plugins: [{FailPlugin, []}])

    log =
      capture_log(fn ->
        assert {:noreply, %{timer: nil}} =
                 Watcher.handle_info(:regenerate, %{ctx: ctx, debounce: 5, timer: make_ref()})
      end)

    assert log =~ "generation failed"
  end
end

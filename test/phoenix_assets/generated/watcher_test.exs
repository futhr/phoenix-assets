defmodule PhoenixAssets.Generated.WatcherTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context}
  alias PhoenixAssets.Generated.Watcher

  defp state do
    ctx = Context.new(Config.load!(otp_app: :my_app), env: :test, plugins: [])
    %{ctx: ctx, debounce: 5, timer: nil, watcher: nil}
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
end

defmodule PhoenixAssets.PlugTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Plug.Test

  alias PhoenixAssets.Plug, as: AssetsPlug

  test "returns status JSON when enabled" do
    conn =
      :get
      |> conn("/__assets/status")
      |> AssetsPlug.call(AssetsPlug.init(enabled: true))

    assert conn.status == 200
    assert conn.halted
    assert {:ok, body} = Jason.decode(conn.resp_body)
    assert Map.has_key?(body, "dev")
    assert Map.has_key?(body, "manifest")
    assert Map.has_key?(body, "version")
  end

  test "passes through when disabled" do
    conn =
      :get
      |> conn("/__assets/status")
      |> AssetsPlug.call(AssetsPlug.init(enabled: false))

    refute conn.halted
    assert conn.status == nil
  end

  test "passes through unrelated paths" do
    conn =
      :get
      |> conn("/other")
      |> AssetsPlug.call(AssetsPlug.init(enabled: true))

    refute conn.halted
  end
end

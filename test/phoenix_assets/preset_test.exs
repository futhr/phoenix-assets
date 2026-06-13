defmodule PhoenixAssets.PresetTest do
  @moduledoc false

  use ExUnit.Case, async: true

  doctest PhoenixAssets.Preset

  defmodule P1 do
    @moduledoc false
    use PhoenixAssets.Plugin
  end

  defmodule P2 do
    @moduledoc false
    use PhoenixAssets.Plugin
    depends_on(PhoenixAssets.PresetTest.P1)
  end

  defmodule Stack do
    @moduledoc false
    use PhoenixAssets.Preset

    integration(PhoenixAssets.PresetTest.P2, foo: 1)
    integration(PhoenixAssets.PresetTest.P1)
  end

  test "resolves integrations into dependency order, preserving opts" do
    assert Stack.plugins() == [{P1, []}, {P2, [foo: 1]}]
  end
end

defmodule PhoenixAssets.PresetErrorTest do
  @moduledoc false

  use ExUnit.Case, async: true

  test "a preset missing a hard dependency fails to compile" do
    assert_raise CompileError, fn ->
      Code.compile_string("""
      defmodule PhoenixAssets.PresetErrorTest.MissingDep do
        use PhoenixAssets.Preset
        # Storybook depends_on SvelteKit, which is absent here.
        integration(PhoenixAssets.Storybook)
      end
      """)
    end
  end
end

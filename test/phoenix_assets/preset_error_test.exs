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

  test "a preset that lists the same integration twice fails to compile" do
    # The resolver's {:duplicate, module} error surfaces as a compile error in
    # the preset module -- the earliest possible feedback for a copy-paste slip.
    error =
      assert_raise CompileError, fn ->
        Code.compile_string("""
        defmodule PhoenixAssets.PresetErrorTest.DuplicateIntegration do
          use PhoenixAssets.Preset
          integration(PhoenixAssets.SvelteKit)
          integration(PhoenixAssets.SvelteKit)
        end
        """)
      end

    assert Exception.message(error) =~ "listed more than once"
  end
end

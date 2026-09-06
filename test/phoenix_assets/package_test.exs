defmodule PhoenixAssets.PackageTest do
  @moduledoc false

  use ExUnit.Case, async: true

  test "the Ash upgrade bounds combining-mark input with the configured codepoint policy" do
    assert Application.fetch_env!(:ash, :default_string_length_count) == :codepoints

    assert {:error, _} =
             Ash.Type.String.apply_constraints("a" <> String.duplicate("\u0301", 20),
               max_length: 2
             )

    assert {:ok, "ab"} = Ash.Type.String.apply_constraints("ab", max_length: 2)
  end
end

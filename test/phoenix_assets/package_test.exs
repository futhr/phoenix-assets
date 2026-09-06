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

  test "the required quality gate includes registry security audits" do
    {config, []} = Code.eval_file(".check.exs")
    assert config[:tools][:hex_audit][:command] == "mix hex.audit"
    assert config[:tools][:npm_audit][:command] == "pnpm audit --prod"
  end


  test "the Hex package exports the host DSL formatter configuration" do
    files = Mix.Project.config()[:package][:files]
    assert ".formatter.exs" in files
    {formatter, []} = Code.eval_file(".formatter.exs")
    exported = formatter[:export][:locals_without_parens]

    for declaration <- [
          command: 2,
          field: 2,
          field: 3,
          integration: 2,
          shape: 2,
          topic: 2,
          type: 2
        ] do
      assert declaration in exported
    end
  end

end

defmodule PhoenixAssets.CanonicalJSONTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.CanonicalJSON

  doctest PhoenixAssets.CanonicalJSON

  test "sorts object keys at every depth" do
    out = CanonicalJSON.encode!(%{"b" => %{"z" => 1, "a" => 2}, "a" => true})

    assert out == """
           {
             "a": true,
             "b": {
               "a": 2,
               "z": 1
             }
           }
           """
  end

  test "sorts keys even beyond the flatmap threshold (hash-ordered maps)" do
    keys = for n <- 1..64, do: "key_#{String.pad_leading(to_string(n), 3, "0")}"
    map = Map.new(keys, &{&1, 1})

    emitted =
      CanonicalJSON.encode!(map)
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "key_"))
      |> Enum.map(&(&1 |> String.trim() |> String.split(":") |> hd()))

    assert emitted == Enum.map(Enum.sort(keys), &~s("#{&1}"))
  end

  test "is byte-stable across construction order" do
    a = %{"x" => Enum.to_list(1..3), "y" => %{"k" => "v"}}
    b = %{"y" => %{"k" => "v"}} |> Map.put("x", [1, 2, 3])

    assert CanonicalJSON.encode!(a) == CanonicalJSON.encode!(b)
  end

  test "normalises atom keys to strings" do
    assert CanonicalJSON.encode!(%{version: 1}) == "{\n  \"version\": 1\n}\n"
  end

  test "preserves list order and renders empty containers compactly" do
    assert CanonicalJSON.encode!(%{"list" => ["b", "a"], "empty" => %{}, "none" => []}) ==
             """
             {
               "empty": {},
               "list": [
                 "b",
                 "a"
               ],
               "none": []
             }
             """
  end

  test "escapes strings exactly like the stdlib JSON encoder" do
    tricky = ~s(quote " backslash \\ newline \n unicode é)
    assert CanonicalJSON.encode!(tricky) == JSON.encode!(tricky) <> "\n"
  end

  test "rejects structs with a clear error" do
    assert_raise ArgumentError, ~r/plain maps, lists, and scalars/, fn ->
      CanonicalJSON.encode!(%{"entry" => ~D[2026-01-01]})
    end
  end

  test "ends with a trailing newline" do
    assert String.ends_with?(CanonicalJSON.encode!(%{}), "\n")
  end
end

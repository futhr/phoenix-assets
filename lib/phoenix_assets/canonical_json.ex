defmodule PhoenixAssets.CanonicalJSON do
  @moduledoc """
  Canonical, byte-stable JSON encoding for the artifacts the library writes.

  Encodes with object keys sorted lexicographically at every depth and
  two-space pretty-printing, so identical data always serialises to identical
  bytes regardless of map size or insertion order. `graph.json` is written
  through this module; a plain map encoder would leak Erlang's map iteration
  order into the file (maps over 32 keys iterate in hash order), making the
  asset graph diff noisily between runs and OTP releases.

  Scalars defer to the stdlib `JSON` encoder, so string escaping matches the
  rest of the library's generated output. Structs are rejected: graph payloads
  are plain data, and silently encoding a struct would hide a plugin bug.

  ## Why

  The generated-contracts engine promises byte-identical output for identical
  input. The graph artifact has to honour the same contract, or tooling that
  diffs or caches it sees phantom changes.
  """

  @doc """
  Encodes `data` as canonical pretty-printed JSON with a trailing newline.

      iex> PhoenixAssets.CanonicalJSON.encode!(%{"b" => [1, true], "a" => nil})
      ~s({\\n  "a": null,\\n  "b": [\\n    1,\\n    true\\n  ]\\n}\\n)
  """
  @spec encode!(term()) :: binary()
  def encode!(data), do: IO.iodata_to_binary([encode(data, 0), "\n"])

  defp encode(struct, _) when is_struct(struct) do
    raise ArgumentError,
          "phoenix_assets: cannot canonically encode struct #{inspect(struct.__struct__)}; " <>
            "graph payloads must be plain maps, lists, and scalars"
  end

  defp encode(map, _) when map_size(map) == 0, do: "{}"

  defp encode(map, depth) when is_map(map) do
    normalized = Enum.map(map, fn {key, value} -> {to_string(key), value} end)
    reject_duplicate_keys!(normalized)

    pairs =
      normalized
      |> Enum.sort_by(fn {key, _} -> key end)
      |> Enum.map(fn {key, value} ->
        [indent(depth + 1), JSON.encode!(key), ": ", encode(value, depth + 1)]
      end)

    ["{\n", Enum.intersperse(pairs, ",\n"), "\n", indent(depth), "}"]
  end

  defp encode([], _), do: "[]"

  defp encode(list, depth) when is_list(list) do
    items = Enum.map(list, fn value -> [indent(depth + 1), encode(value, depth + 1)] end)
    ["[\n", Enum.intersperse(items, ",\n"), "\n", indent(depth), "]"]
  end

  defp encode(other, _), do: JSON.encode!(other)

  # A map keyed by both `:a` and `"a"` normalises to two identical string keys;
  # sorting and emitting both would silently produce duplicate JSON keys, so we
  # fail loudly instead — matching the module's reject-on-ambiguity policy.
  defp reject_duplicate_keys!(pairs) do
    keys = Enum.map(pairs, fn {key, _} -> key end)

    case keys -- Enum.uniq(keys) do
      [] ->
        :ok

      dups ->
        raise ArgumentError,
              "phoenix_assets: cannot canonically encode map with duplicate keys " <>
                "after normalisation: #{inspect(Enum.uniq(dups))}"
    end
  end

  defp indent(depth), do: String.duplicate("  ", depth)
end

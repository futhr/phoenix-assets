defmodule PhoenixAssets.Generators.Typespec do
  @moduledoc """
  Renders named Elixir typespecs as TypeScript declarations.

  The source module, declaration order, root union name, output path, and optional
  trailer are supplied by the host. Product type names never live in this module.
  """

  alias Code.Typespec
  alias PhoenixAssets.Generators.TS

  @type option ::
          {:types, [atom()]}
          | {:root, atom()}
          | {:root_name, String.t()}
          | {:discriminator_name, String.t()}
          | {:trailer, String.t()}

  @doc "Fetches types from `source_module` and renders configured TypeScript."
  @spec render(module(), [option()]) :: {:ok, String.t()} | :error
  def render(source_module, opts) when is_atom(source_module) and is_list(opts) do
    with {:ok, types} <- Typespec.fetch_types(source_module) do
      type_map = Map.new(types, fn {:type, {name, body, _}} -> {name, body} end)
      {:ok, render_map(type_map, source_module, opts)}
    end
  end

  @doc "Writes rendered types to the configured output path."
  @spec write(module(), Path.t(), [option()]) :: :ok | :error | {:error, term()}
  def write(source_module, output, opts) do
    with {:ok, rendered} <- render(source_module, opts),
         :ok <- File.mkdir_p(Path.dirname(output)) do
      File.write(output, rendered)
    end
  end

  defp render_map(type_map, source_module, opts) do
    root = Keyword.get(opts, :root, :t)
    names = Keyword.get(opts, :types, type_map |> Map.keys() |> Enum.sort())
    root_name = Keyword.get(opts, :root_name, TS.type_name(root))
    discriminator_name = Keyword.get(opts, :discriminator_name)

    sections =
      [
        TS.header() |> String.trim_trailing(),
        "// Source: #{inspect(source_module)}",
        render_discriminator(type_map[root], type_map, discriminator_name),
        render_root(type_map[root], root_name),
        names
        |> Enum.reject(&(&1 == root))
        |> Enum.filter(&Map.has_key?(type_map, &1))
        |> Enum.map_join("\n\n", &render_type(&1, type_map[&1], type_map)),
        Keyword.get(opts, :trailer, "") |> String.trim()
      ]
      |> Enum.reject(&(&1 in [nil, ""]))

    Enum.join(sections, "\n\n") <> "\n"
  end

  defp render_discriminator(_, _, nil), do: nil

  defp render_discriminator({:type, _, :union, variants}, type_map, name) do
    values =
      Enum.map(variants, fn
        {:user_type, _, ref, []} -> discriminator(type_map[ref], ref)
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    "export type #{TS.type_name(name)} = #{TS.string_union(values)}"
  end

  defp render_discriminator(_, _, _), do: nil

  defp discriminator({:type, _, :map, fields}, fallback) do
    Enum.find_value(fields, Atom.to_string(fallback), fn
      {:type, _, :map_field_exact, [{:atom, _, :type}, {:atom, _, value}]} ->
        Atom.to_string(value)

      _ ->
        nil
    end)
  end

  defp discriminator(_, fallback), do: Atom.to_string(fallback)

  defp render_root({:type, _, :union, variants}, name) do
    members =
      Enum.map_join(variants, "\n", fn
        {:user_type, _, member, []} -> "  | #{TS.type_name(member)}"
        other -> "  | #{to_ts_type(other, %{})}"
      end)

    "export type #{TS.type_name(name)} =\n#{members}"
  end

  defp render_root(body, name), do: "export type #{TS.type_name(name)} = #{to_ts_type(body, %{})}"

  defp render_type(name, {:type, _, :map, empty}, _) when empty in [[], :any] do
    "export type #{TS.type_name(name)} = Record<string, unknown>"
  end

  defp render_type(name, {:type, _, :map, fields}, type_map) when is_list(fields) do
    lines =
      Enum.map_join(fields, "\n", fn
        {:type, _, :map_field_exact, [{:atom, _, key}, value]} ->
          "  #{TS.camelize(key)}: #{to_ts_type(value, type_map)}"

        {:type, _, :map_field_assoc, [key, value]} ->
          "  [key: #{to_ts_type(key, type_map)}]: #{to_ts_type(value, type_map)}"
      end)

    "export interface #{TS.type_name(name)} {\n#{lines}\n}"
  end

  defp render_type(name, body, type_map) do
    "export type #{TS.type_name(name)} = #{to_ts_type(body, type_map)}"
  end

  defp to_ts_type({:atom, _, nil}, _), do: "null"
  defp to_ts_type({:atom, _, literal}, _) when is_atom(literal), do: TS.string_union([literal])

  defp to_ts_type({:type, _, :union, variants}, type_map) do
    Enum.map_join(variants, " | ", &to_ts_type(&1, type_map))
  end

  defp to_ts_type({:user_type, _, name, []}, _), do: TS.type_name(name)

  defp to_ts_type({:remote_type, _, [{:atom, _, module}, {:atom, _, :t}, []]}, _)
       when module in [String, Date, DateTime, NaiveDateTime],
       do: TS.primitive(:string)

  defp to_ts_type({:type, _, :list, [element]}, type_map),
    do: "#{to_ts_type(element, type_map)}[]"

  defp to_ts_type({:type, _, :map, :any}, _), do: TS.primitive(:map)

  defp to_ts_type({:type, _, :map, fields}, type_map) when is_list(fields) do
    fields
    |> Enum.map_join("; ", fn
      {:type, _, kind, [{:atom, _, key}, value]}
      when kind in [:map_field_exact, :map_field_assoc] ->
        "#{TS.camelize(key)}: #{to_ts_type(value, type_map)}"

      {:type, _, _, [key, value]} ->
        "[key: #{to_ts_type(key, type_map)}]: #{to_ts_type(value, type_map)}"
    end)
    |> then(&"{ #{&1} }")
  end

  defp to_ts_type({:type, _, type, []}, _) do
    case type do
      nil -> "null"
      :term -> "unknown"
      :any -> "unknown"
      :atom -> "string"
      other -> TS.primitive(other)
    end
  end

  defp to_ts_type(_, _), do: "unknown"
end

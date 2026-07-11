defmodule PhoenixAssets.PubSub do
  @moduledoc """
  Integration plugin that generates typed PubSub topic builders and an event union.

  Reads the topics declared in the module passed as `topics:` (see
  `PhoenixAssets.PubSub.Topics`) and emits `pubsub.ts`: a builder per topic
  (substituting `{param}` placeholders) and a discriminated `PubSubEvent` union
  over every topic/event pair, with payloads typed from `$phoenix/types` or from
  inline field maps.

  """

  use PhoenixAssets.Plugin

  alias PhoenixAssets.{GeneratedFile, Graph}
  alias PhoenixAssets.Generators.TS

  @placeholder ~r/\{(\w+)\}/

  @impl PhoenixAssets.Plugin
  def init(opts, ctx), do: {:ok, %{module: opts[:topics] || ctx.config.stack[:topics]}}

  @impl PhoenixAssets.Plugin
  def generated_files(_, %{module: nil}), do: []

  def generated_files(ctx, %{module: module}) do
    [
      GeneratedFile.new(
        path: Path.join(ctx.generated_dir, "pubsub.ts"),
        contents: render(topics(module)),
        plugin: :pubsub,
        kind: :pubsub
      )
    ]
  end

  @impl PhoenixAssets.Plugin
  def graph_entries(_, %{module: nil}), do: []

  def graph_entries(_, %{module: module}) do
    Enum.map(topics(module), fn {name, opts} ->
      events =
        opts |> Keyword.get(:events, []) |> Enum.map(fn {event, _} -> to_string(event) end)

      Graph.Entry.new(
        kind: :pubsub_topic,
        key: to_string(name),
        data: %{"pattern" => opts[:pattern], "events" => events}
      )
    end)
  end

  defp topics(module), do: module.__phoenix_assets_topics__()

  defp render(topics) do
    sorted = Enum.sort_by(topics, fn {name, _} -> to_string(name) end)
    types = type_imports(sorted)

    [
      TS.header(),
      TS.type_import(types),
      "\nexport const topics = {\n",
      Enum.map(sorted, &render_topic/1),
      "} as const\n\n",
      render_event_union(sorted)
    ]
    |> IO.iodata_to_binary()
  end

  defp type_imports(topics) do
    for {_, opts} <- topics,
        {_, payload} <- Keyword.get(opts, :events, []),
        not is_map(payload),
        uniq: true do
      TS.type_name(payload)
    end
    |> Enum.sort()
  end

  defp render_topic({name, opts}) do
    pattern = opts[:pattern]
    fname = name |> TS.camelize() |> TS.object_key()

    case placeholder_params(pattern) do
      [] ->
        "  #{fname}: () => #{JSON.encode!(pattern)},\n"

      params ->
        args = Enum.map_join(params, ", ", &"#{TS.arg_name(&1)}: string | number")
        "  #{fname}: (#{args}) => `#{placeholder_template(pattern)}`,\n"
    end
  end

  defp render_event_union(topics) do
    members =
      for {name, opts} <- topics, {event, payload} <- Keyword.get(opts, :events, []) do
        "  | { type: #{JSON.encode!("#{name}:#{event}")}; payload: #{payload_type(payload)} }"
      end

    case members do
      [] -> "export type PubSubEvent = never\n"
      _ -> "export type PubSubEvent =\n" <> Enum.join(members, "\n") <> "\n"
    end
  end

  defp payload_type(payload) when is_map(payload) do
    body =
      payload
      |> Enum.sort_by(fn {field, _} -> to_string(field) end)
      |> Enum.map_join("; ", fn {field, type} ->
        "#{TS.object_key(field)}: #{TS.primitive(type)}"
      end)

    "{ " <> body <> " }"
  end

  defp payload_type(payload), do: TS.type_name(payload)

  defp placeholder_params(pattern) do
    @placeholder |> Regex.scan(pattern) |> Enum.map(fn [_, param] -> param end) |> Enum.uniq()
  end

  defp placeholder_template(pattern) do
    Regex.replace(@placeholder, pattern, fn _, param -> "${#{TS.arg_name(param)}}" end)
  end
end

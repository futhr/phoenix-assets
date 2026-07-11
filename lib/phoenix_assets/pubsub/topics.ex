defmodule PhoenixAssets.PubSub.Topics do
  @moduledoc """
  DSL for declaring Phoenix PubSub topics and their event payloads.

  A host module `use`s this and declares each topic's pattern and events:

      defmodule MyApp.Assets.PubSubTopics do
        use PhoenixAssets.PubSub.Topics

        topic :device,
          pattern: "device:{id}",
          events: [updated: "Device", deleted: %{id: :string}]
      end

  An event payload is either a TypeScript type name (a string or module-like
  atom resolved against `$phoenix/types`) or an inline map of field to
  primitive type. Declarations are validated at compile time: a missing
  `pattern:`, an unknown option, or a malformed event payload is a compile
  error rather than a crash mid-generation.

  > #### `use PhoenixAssets.PubSub.Topics` {: .info}
  >
  > Using this module imports `topic/2` and defines
  > `__phoenix_assets_topics__/0` with the validated declarations.

  """

  @topic_schema NimbleOptions.new!(
                  pattern: [
                    type: :string,
                    required: true,
                    doc: "the topic string, with `{param}` placeholders"
                  ],
                  events: [
                    type: :keyword_list,
                    default: [],
                    doc: "event name to payload (a type name or an inline field map)"
                  ]
                )

  @placeholder ~r/\{(\w+)\}/
  @js_identifier ~r/^[A-Za-z_$][\w$]*$/
  @primitive_types [
    :string,
    :binary,
    :id,
    :uuid,
    :date,
    :datetime,
    :integer,
    :float,
    :number,
    :decimal,
    :boolean,
    :map
  ]

  alias PhoenixAssets.Generators.TS

  @doc false
  defmacro __using__(_) do
    quote do
      import PhoenixAssets.PubSub.Topics, only: [topic: 2]
      Module.register_attribute(__MODULE__, :phoenix_assets_topics, accumulate: true)
      @before_compile PhoenixAssets.PubSub.Topics
    end
  end

  @doc "Declares a PubSub topic: `pattern:` and `events:`."
  defmacro topic(name, opts) do
    quote do
      @phoenix_assets_topics {unquote(name), unquote(opts)}
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    topics =
      env.module
      |> Module.get_attribute(:phoenix_assets_topics)
      |> List.wrap()
      |> Enum.reverse()
      |> Enum.map(fn {name, opts} -> {name, validate!(env, name, opts)} end)

    ensure_unique_names!(env, topics)

    quote do
      @doc "Returns the declared PubSub topics as `{name, opts}` pairs."
      def __phoenix_assets_topics__, do: unquote(Macro.escape(topics))
    end
  end

  defp ensure_unique_names!(env, topics) do
    names = Enum.map(topics, fn {name, _} -> name end)

    case names -- Enum.uniq(names) do
      [] -> :ok
      [dup | _] -> compile_error!(env, dup, "declared more than once")
    end
  end

  defp validate!(env, name, opts) do
    opts =
      case NimbleOptions.validate(opts, @topic_schema) do
        {:ok, validated} -> validated
        {:error, error} -> compile_error!(env, name, Exception.message(error))
      end

    validate_pattern!(env, name, opts[:pattern])

    Enum.each(opts[:events], fn {event, payload} ->
      unless valid_payload?(payload) do
        compile_error!(
          env,
          name,
          "event #{inspect(event)} payload must be a type name (string or module) " <>
            "or a map of field => primitive atom, got: #{inspect(payload)}"
        )
      end

      if not is_map(payload), do: TS.type_name(payload)
    end)

    opts
  rescue
    error in ArgumentError -> compile_error!(env, name, Exception.message(error))
  end

  # The pattern is spliced into a TS template literal, so a backtick or a `${`
  # would break or inject the generated builder; placeholders become function
  # arguments, so they must be unique, valid JS identifiers.
  defp validate_pattern!(env, name, pattern) do
    if String.contains?(pattern, "`") or String.contains?(pattern, "${") do
      compile_error!(env, name, "pattern #{inspect(pattern)} must not contain a backtick or `${`")
    end

    params = @placeholder |> Regex.scan(pattern) |> Enum.map(fn [_, param] -> param end)

    Enum.each(params, fn param ->
      unless Regex.match?(@js_identifier, param) do
        compile_error!(env, name, "placeholder #{inspect(param)} is not a valid JS identifier")
      end
    end)

    if params != Enum.uniq(params) do
      compile_error!(env, name, "pattern #{inspect(pattern)} repeats a placeholder")
    end
  end

  defp valid_payload?(payload)
       when is_binary(payload) or (is_atom(payload) and payload not in [nil, true, false]),
       do: true

  defp valid_payload?(payload) when is_map(payload) do
    Enum.all?(payload, fn {field, type} -> is_atom(field) and type in @primitive_types end)
  end

  defp valid_payload?(_), do: false

  @spec compile_error!(Macro.Env.t(), term(), String.t()) :: no_return()
  defp compile_error!(env, name, message),
    do: PhoenixAssets.DSL.compile_error!(env, "topic", name, message)
end

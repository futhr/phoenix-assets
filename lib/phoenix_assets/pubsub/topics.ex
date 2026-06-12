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

  ## Why

  Topic strings and event shapes are otherwise scattered, stringly-typed, and
  easy to mistype. Declaring them once lets `PhoenixAssets.PubSub` generate
  typed topic builders and a discriminated `PubSubEvent` union.
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

    quote do
      @doc "Returns the declared PubSub topics as `{name, opts}` pairs."
      def __phoenix_assets_topics__, do: unquote(Macro.escape(topics))
    end
  end

  defp validate!(env, name, opts) do
    opts =
      case NimbleOptions.validate(opts, @topic_schema) do
        {:ok, validated} -> validated
        {:error, error} -> compile_error!(env, name, Exception.message(error))
      end

    Enum.each(opts[:events], fn {event, payload} ->
      unless valid_payload?(payload) do
        compile_error!(
          env,
          name,
          "event #{inspect(event)} payload must be a type name (string or module) " <>
            "or a map of field => primitive atom, got: #{inspect(payload)}"
        )
      end
    end)

    opts
  end

  defp valid_payload?(payload) when is_binary(payload) or is_atom(payload), do: true

  defp valid_payload?(payload) when is_map(payload) do
    Enum.all?(payload, fn {field, type} -> is_atom(field) and is_atom(type) end)
  end

  defp valid_payload?(_), do: false

  defp compile_error!(env, name, message) do
    raise CompileError,
      file: env.file,
      line: env.line,
      description: "phoenix_assets topic #{inspect(name)}: #{message}"
  end
end

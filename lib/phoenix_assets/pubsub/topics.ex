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

  An event payload is either a TypeScript type name (a string or module-like atom
  resolved against `$phoenix/types`) or an inline map of field to primitive type.

  ## Why

  Topic strings and event shapes are otherwise scattered, stringly-typed, and
  easy to mistype. Declaring them once lets `PhoenixAssets.PubSub` generate typed
  topic builders and a discriminated `PubSubEvent` union.
  """

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
      env.module |> Module.get_attribute(:phoenix_assets_topics) |> List.wrap() |> Enum.reverse()

    quote do
      @doc "Returns the declared PubSub topics as `{name, opts}` pairs."
      def __phoenix_assets_topics__, do: unquote(Macro.escape(topics))
    end
  end
end

defmodule PhoenixAssets.Graph.Entry do
  @moduledoc """
  One node in the Phoenix Asset Graph.

  Plugins emit entries from `c:PhoenixAssets.Plugin.graph_entries/2`. The graph
  builder collects them, merges the Vite manifest, and writes the combined
  `graph.json` plus an optional compiled lookup module.

  `kind` identifies what the entry describes; `key` is its stable identifier
  within that kind; `data` holds the kind-specific payload; `source` is an
  optional path to the file a developer would open for this entry.

  """

  @type kind ::
          :page
          | :route
          | :electric_shape
          | :command
          | :session
          | :pubsub_topic
          | :entry
          | :locale
          | :story
          | atom()

  @type t :: %__MODULE__{
          kind: kind(),
          key: String.t(),
          data: map(),
          source: String.t() | nil
        }

  @enforce_keys [:kind, :key]
  defstruct [:kind, :key, :source, data: %{}]

  @doc "Builds a graph entry from a keyword list or map of attributes."
  @spec new(Enumerable.t()) :: t()
  def new(attrs), do: struct!(__MODULE__, attrs)
end

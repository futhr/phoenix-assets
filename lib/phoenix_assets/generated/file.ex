defmodule PhoenixAssets.GeneratedFile do
  @moduledoc """
  A single generated frontend-contract file contributed by a plugin.

  Plugins return these from `c:PhoenixAssets.Plugin.generated_files/2`. The
  generated engine writes each one to `path` (relative to the asset root),
  rewriting only when the contents actually change so the Vite HMR graph is not
  triggered by no-op writes.

  ## Why

  Treating generated output as data (a struct) rather than a side effect lets the
  engine diff it for staleness (`mix phoenix_assets.gen --check`), order it
  deterministically, and attribute each file to the plugin that produced it.
  """

  @type kind ::
          :routes | :types | :env | :electric | :pubsub | :locales | :graph_module | atom()

  @type t :: %__MODULE__{
          path: Path.t(),
          contents: iodata(),
          plugin: atom() | nil,
          kind: kind() | nil
        }

  @enforce_keys [:path, :contents]
  defstruct [:path, :contents, :plugin, :kind]

  @doc "Builds a generated file from a keyword list or map of attributes."
  @spec new(Enumerable.t()) :: t()
  def new(attrs), do: struct!(__MODULE__, attrs)
end

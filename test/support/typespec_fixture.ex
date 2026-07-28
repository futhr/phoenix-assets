defmodule PhoenixAssets.Test.TypespecFixture do
  @moduledoc false

  @type created :: %{type: :created, user_id: integer(), labels: [String.t()]}
  @type removed :: %{type: :removed, reason: String.t() | nil}
  @type t :: created() | removed()
end

defmodule PhoenixAssets.Test.TypespecFixture.Untyped do
  @moduledoc false
  # Deliberately declares no `@type`, so the "nothing to render" path has
  # something honest to fail against.

  @doc false
  def noop, do: :ok
end

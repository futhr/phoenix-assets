defmodule PhoenixAssets.Test.TypespecFixture do
  @moduledoc false

  @type created :: %{type: :created, user_id: integer(), labels: [String.t()]}
  @type removed :: %{type: :removed, reason: String.t() | nil}
  @type t :: created() | removed()
end

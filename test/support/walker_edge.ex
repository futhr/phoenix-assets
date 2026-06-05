defmodule PhoenixAssets.TestSupport.WalkerState do
  @moduledoc false

  use Ash.Type.Enum, values: [:open, :closed]
end

defmodule PhoenixAssets.TestSupport.WalkerEdge do
  @moduledoc """
  Resource exercising Walker branches the KitchenSink does not reach: a bare
  `:atom` attribute (no `one_of`), an `Ash.Type.Enum` module attribute, an
  exposed non-public attribute, and a calculation pulled in via the
  `:calculations` option.
  """

  use Ash.Resource, domain: nil, validate_domain_inclusion?: false

  attributes do
    uuid_primary_key :id

    attribute :name, :string, public?: true, allow_nil?: false

    attribute :kind, :atom,
      public?: true,
      allow_nil?: false,
      description: "bare atom with no one_of constraint, so Walker maps it to string"

    attribute :state, PhoenixAssets.TestSupport.WalkerState,
      public?: true,
      allow_nil?: false,
      description: "Ash.Type.Enum module, so Walker renders its values as a string union"

    attribute :hidden, :string,
      public?: false,
      description: "non-public, reachable only through the :expose option"
  end

  calculations do
    calculate(:label, :string, expr(name),
      description: "resolved through its declared type via the :calculations option"
    )
  end
end

defmodule PhoenixAssets.TestSupport.WalkerEdge do
  @moduledoc """
  Resource exercising Walker branches the KitchenSink does not reach: a bare
  `:atom` attribute (no `one_of`), an exposed non-public attribute, and a
  calculation pulled in via the `:calculations` option.
  """

  use Ash.Resource, domain: nil, validate_domain_inclusion?: false

  attributes do
    uuid_primary_key :id

    attribute :name, :string, public?: true, allow_nil?: false

    attribute :kind, :atom,
      public?: true,
      allow_nil?: false,
      description: "bare atom with no one_of constraint, so Walker maps it to string"

    attribute :hidden, :string,
      public?: false,
      description: "non-public, reachable only through the :expose option"
  end

  calculations do
    calculate :label, :string, expr(name),
      description: "resolved through its declared type via the :calculations option"
  end
end

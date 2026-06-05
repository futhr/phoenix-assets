defmodule PhoenixAssets.TestSupport.Gated do
  @moduledoc """
  Resource with field policies, exercising the Types field-policy doctor warning:
  `:email` is public yet policy-gated, so exposing it in a generated type should
  be flagged. The catch-all `field_policy :*` satisfies Ash's requirement that
  every public field be covered once any field policy exists.
  """

  use Ash.Resource,
    domain: nil,
    validate_domain_inclusion?: false,
    authorizers: [Ash.Policy.Authorizer]

  actions do
    defaults [:read]
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string, public?: true, allow_nil?: false

    attribute :email, :string,
      public?: true,
      allow_nil?: false,
      description: "public yet field-policy gated, so Types should warn when it is exposed"
  end

  field_policies do
    field_policy :email do
      authorize_if always()
    end

    field_policy :* do
      authorize_if always()
    end
  end
end

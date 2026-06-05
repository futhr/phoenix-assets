defmodule PhoenixAssets.TestSupport.Portfolio do
  @moduledoc false

  use Ash.Resource, domain: nil, validate_domain_inclusion?: false

  attributes do
    uuid_primary_key :id

    attribute :title, :string, public?: true, allow_nil?: false

    attribute :visibility, :atom,
      public?: true,
      constraints: [one_of: [:public, :private, :unlisted]]

    attribute :view_count, :integer, public?: true, allow_nil?: false
    attribute :hourly_rate, :decimal, public?: true, allow_nil?: true
    attribute :skills, {:array, :string}, public?: true, allow_nil?: false
    attribute :metadata, :map, public?: true, allow_nil?: false
    attribute :inserted_at, :utc_datetime_usec, public?: true, allow_nil?: false
    attribute :secret_token, :string, public?: true, sensitive?: true
    attribute :internal_note, :string, public?: false
  end
end

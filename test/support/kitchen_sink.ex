defmodule PhoenixAssets.TestSupport.Address do
  @moduledoc false

  use Ash.Resource, data_layer: :embedded, validate_domain_inclusion?: false

  attributes do
    attribute :street, :string, public?: true, allow_nil?: false
    attribute :zip, :string, public?: true, allow_nil?: false
  end
end

defmodule PhoenixAssets.TestSupport.Priority do
  @moduledoc false

  use Ash.Type.NewType, subtype_of: :string
end

defmodule PhoenixAssets.TestSupport.KitchenSink do
  @moduledoc false

  use Ash.Resource, domain: nil, validate_domain_inclusion?: false

  alias PhoenixAssets.TestSupport.{Address, Priority}

  attributes do
    uuid_primary_key :id

    attribute :name, :string, public?: true, allow_nil?: false
    attribute :slug, :ci_string, public?: true, allow_nil?: false
    attribute :count, :integer, public?: true, allow_nil?: false
    attribute :ratio, :float, public?: true, allow_nil?: false
    attribute :price, :decimal, public?: true, allow_nil?: true
    attribute :active, :boolean, public?: true, allow_nil?: false
    attribute :due_on, :date, public?: true, allow_nil?: false
    attribute :created_at, :utc_datetime_usec, public?: true, allow_nil?: false

    attribute :status, :atom,
      public?: true,
      allow_nil?: false,
      constraints: [one_of: [:draft, :published]]

    attribute :tags, {:array, :string}, public?: true, allow_nil?: false
    attribute :meta, :map, public?: true, allow_nil?: false

    attribute :dimensions, :map,
      public?: true,
      allow_nil?: false,
      constraints: [fields: [width: [type: :integer], height: [type: :integer]]]

    attribute :address, Address, public?: true, allow_nil?: true
    attribute :priority, Priority, public?: true, allow_nil?: false

    attribute :payload, :union,
      public?: true,
      allow_nil?: false,
      constraints: [types: [note: [type: :string], score: [type: :integer]]]

    attribute :api_secret, :string, public?: true, sensitive?: true
    attribute :internal_flag, :boolean, public?: false
  end
end

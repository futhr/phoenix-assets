defmodule PhoenixAssets.Types.WalkerEmbeddedTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias PhoenixAssets.Types.Walker

  defp compile_quiet(source) do
    capture_io(:stderr, fn -> Code.compile_string(source) end)
    :ok
  end

  setup_all do
    # Sibling re-use: one embedded resource referenced by two attributes.
    compile_quiet("""
    defmodule WalkerEmb.Address do
      use Ash.Resource, data_layer: :embedded

      attributes do
        attribute :street, :string, public?: true, allow_nil?: false
        attribute :city, :string, public?: true, allow_nil?: false
      end
    end

    defmodule WalkerEmb.Contact do
      use Ash.Resource, domain: nil, validate_domain_inclusion?: false

      attributes do
        uuid_primary_key :id
        attribute :home, WalkerEmb.Address, public?: true
        attribute :work, WalkerEmb.Address, public?: true
      end
    end
    """)

    # A genuine embedding cycle. Ash rejects declared cycles at compile time
    # (Ash.Type.detect_type_cycle!), so build one the only way it can exist at
    # runtime: compile Leaf without references, compile Mid embedding Leaf,
    # then redefine Leaf to embed Mid -- Leaf -> Mid -> Leaf.
    compile_quiet("""
    defmodule WalkerEmb.Leaf do
      use Ash.Resource, data_layer: :embedded

      attributes do
        attribute :value, :string, public?: true, allow_nil?: false
      end
    end
    """)

    compile_quiet("""
    defmodule WalkerEmb.Mid do
      use Ash.Resource, data_layer: :embedded

      attributes do
        attribute :leaf, WalkerEmb.Leaf, public?: true, allow_nil?: false
      end
    end
    """)

    compile_quiet("""
    defmodule WalkerEmb.Leaf do
      use Ash.Resource, data_layer: :embedded

      attributes do
        attribute :value, :string, public?: true, allow_nil?: false
        attribute :mid, WalkerEmb.Mid, public?: true, allow_nil?: false
      end
    end
    """)

    :ok
  end

  test "an embedded resource re-used on sibling branches is inlined on both" do
    [{:home, home}, {:id, _}, {:work, work}] =
      WalkerEmb.Contact |> Walker.fields(only: :public) |> Enum.sort()

    assert home == "{ city: string; street: string } | null"
    assert work == home
  end

  test "a cyclic embedding terminates, rendering unknown at the recursion point" do
    fields = Walker.fields(WalkerEmb.Leaf, only: :public)

    assert {:mid, "{ leaf: unknown }"} in fields
    assert {:value, "string"} in fields
  end

  test "rendering a cyclic embedding is deterministic" do
    decls = [{"LeafRow", [resource: WalkerEmb.Leaf, only: :public]}]
    assert Walker.render(decls) == Walker.render(decls)
  end
end

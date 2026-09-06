defmodule PhoenixAssets.Integration.PhoenixSyncTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Electric, Graph}

  defmodule Router do
    @moduledoc false
    use Phoenix.Router
    import Phoenix.Sync.Router

    sync("/shapes/items", table: "items")

    scope "/shapes/accounts/:account_id" do
      sync("/items", table: "items")
    end
  end

  defmodule Shapes do
    @moduledoc false
    use PhoenixAssets.Electric.Shapes

    shape(:items, route: "/shapes/items", type: "Item")

    shape(:account_items,
      route: "/shapes/accounts/:account_id/items",
      type: "Item",
      params: [:account_id]
    )
  end

  test "real Phoenix Sync routes remain compatible with generated contracts and diagnostics" do
    ctx =
      Context.new(Config.load!(otp_app: :my_app, router: Router),
        env: :test,
        plugins: [{Electric, shapes: Shapes}]
      )

    {:ok, state} = Electric.init([shapes: Shapes], ctx)
    checks = Electric.doctor_checks(ctx, state)
    assert length(checks) == 2
    assert Enum.all?(checks, &(&1.run.(ctx).status == :ok))

    [file] = Electric.generated_files(ctx, state)
    output = IO.iodata_to_binary(file.contents)
    assert output =~ "accountItems: (params: { account_id: string | number }"
    assert output =~ ~s|createShapeUrl("/shapes/accounts/:account_id/items", params)|

    graph = Graph.build(ctx, manifest: %{})
    assert map_size(graph["electric_shapes"]) == 2
  end
end

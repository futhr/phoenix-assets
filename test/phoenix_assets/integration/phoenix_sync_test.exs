defmodule PhoenixAssets.Integration.PhoenixSyncTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Electric.Client, as: SyncClient
  alias Electric.Client.Fetch.HTTP
  alias Phoenix.Sync.Electric.ClientAdapter
  alias PhoenixAssets.{Config, Context, Electric, Graph}

  defmodule Upstream do
    @moduledoc false
    @behaviour Plug
    @impl true
    def init(opts), do: opts
    @impl true
    def call(conn, {owner, body}) do
      conn = Plug.Conn.fetch_query_params(conn)
      send(owner, {:upstream_params, conn.query_params})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.put_resp_header("electric-handle", "assets-qualified-shape")
      |> Plug.Conn.put_resp_header("electric-offset", "0_0")
      |> Plug.Conn.put_resp_header("electric-has-data", "true")
      |> Plug.Conn.put_resp_header("electric-up-to-date", "true")
      |> Plug.Conn.put_resp_header("retry-after", "1")
      |> Plug.Conn.send_resp(200, body)
    end
  end

  defmodule Endpoint do
    @moduledoc false
    def config(:phoenix_sync), do: Process.get({__MODULE__, :api})
  end

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

  test "a real sync route forwards shape data and Electric 1.8 response headers" do
    owner = self()

    payload =
      JSON.encode!(%{
        "key" => "items/1",
        "value" => %{"id" => "1"},
        "headers" => %{"operation" => "insert"}
      })

    body =
      "[" <> payload <> "," <> JSON.encode!(%{"headers" => %{"control" => "up-to-date"}}) <> "]"

    upstream =
      start_supervised!({Bandit, plug: {Upstream, {owner, body}}, ip: {127, 0, 0, 1}, port: 0})

    {:ok, {_, port}} = ThousandIsland.listener_info(upstream)

    client =
      SyncClient.new!(
        base_url: "http://127.0.0.1:#{port}",
        fetch: {HTTP, request: [raw: true]}
      )

    Process.put({Endpoint, :api}, %ClientAdapter{client: client})

    response =
      :get
      |> Plug.Test.conn("/shapes/items?offset=-1&table=untrusted")
      |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
      |> Router.call(Router.init([]))

    assert response.status == 200
    assert response.resp_body == body
    assert_received {:upstream_params, %{"table" => "items", "offset" => "-1"}}
    assert Plug.Conn.get_resp_header(response, "electric-has-data") == ["true"]
    assert Plug.Conn.get_resp_header(response, "retry-after") == ["1"]

    [exposed] = Plug.Conn.get_resp_header(response, "access-control-expose-headers")
    headers = exposed |> String.split(",") |> Enum.map(&String.trim/1)
    assert "electric-has-data" in headers
    assert "retry-after" in headers
  end
end

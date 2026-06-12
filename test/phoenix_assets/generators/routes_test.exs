defmodule PhoenixAssets.Generators.RoutesTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context}
  alias PhoenixAssets.Generators.Routes

  defmodule Stub do
    @moduledoc false
    def init(opts), do: opts
    def call(conn, _), do: conn
  end

  defmodule Router do
    @moduledoc false
    use Phoenix.Router

    alias PhoenixAssets.Generators.RoutesTest.Stub

    get("/", Stub, :index)
    get("/api/health", Stub, :health)
    get("/api/classes/:new", Stub, :reserved_param)
    get("/api/files/*path", Stub, :file_download)

    scope "/shapes" do
      get("/portfolios", Stub, :public_portfolios)
      get("/portfolios/:slug", Stub, :portfolio_by_slug)
      get("/users/:user_id/portfolios", Stub, :user_portfolios)
    end
  end

  defmodule EdgeRouter do
    @moduledoc false
    use Phoenix.Router

    alias PhoenixAssets.Generators.RoutesTest.Stub

    get("/api/ping", Stub, nil)
    forward("/api/hook", Stub)
    get("/api/health", Stub, :health)
    get("/shapes/health", Stub, :health)
  end

  defmodule EmptyRouter do
    @moduledoc false
    use Phoenix.Router

    get("/", PhoenixAssets.Generators.RoutesTest.Stub, :index)
  end

  defmodule CollisionRouter do
    @moduledoc false
    use Phoenix.Router

    alias PhoenixAssets.Generators.RoutesTest.Stub

    get("/api/thing", Stub, :thing)
    get("/shapes/thing", Stub, :thing)
    get("/shapes/thing2", Stub, :thing2)
  end

  defp generate(router \\ Router) do
    ctx = Context.new(Config.load!(otp_app: :my_app, router: router), env: :test)
    ctx |> Routes.generate() |> Map.fetch!(:contents) |> IO.iodata_to_binary()
  end

  test "generates typed helpers for /shapes and /api endpoints" do
    ts = generate()

    assert ts =~ ~s|health: () => "/api/health"|
    assert ts =~ ~s|publicPortfolios: () => "/shapes/portfolios"|
  end

  test "renders path parameters with consistent camelCase argument and template names" do
    ts = generate()

    assert ts =~ "portfolioBySlug: (slug: string | number) =>"
    assert ts =~ "encodeURIComponent(String(slug))"
    assert ts =~ "userPortfolios: (userId: string | number) =>"
    assert ts =~ "encodeURIComponent(String(userId))"
  end

  test "excludes frontend page routes" do
    refute generate() =~ "index:"
  end

  test "a param named after a TS reserved word is sanitised consistently" do
    ts = generate()

    assert ts =~ "reservedParam: (new_: string | number) =>"
    assert ts =~ "/api/classes/${encodeURIComponent(String(new_))}"
    refute ts =~ "(new: string"
  end

  test "a glob segment becomes a parameter that preserves slashes, encoded per segment" do
    ts = generate()

    assert ts =~ "fileDownload: (path: string | number) =>"

    assert ts =~
             ~s|/api/files/${String(path).split("/").map(encodeURIComponent).join("/")}|
  end

  test "is deterministic" do
    assert generate() == generate()
  end

  test "returns nil when no router is configured" do
    ctx = Context.new(Config.load!(otp_app: :my_app), env: :test)
    assert Routes.generate(ctx) == nil
  end

  test "names routes by helper (no action) and by path slug (forward)" do
    ts = generate(EdgeRouter)

    assert ts =~ "stub: () =>"
    assert ts =~ "apiHook: () =>"
  end

  test "disambiguates duplicate route names with a numeric suffix" do
    ts = generate(EdgeRouter)

    assert ts =~ "health: () =>"
    assert ts =~ "health2: () =>"
  end

  test "a renamed duplicate never collides with an existing route name" do
    ts = generate(CollisionRouter)

    assert ts =~ "thing: () =>"
    assert ts =~ "thing2: () =>"
    assert ts =~ "thing22: () =>"
  end

  test "emits an empty map and a never RouteName union with no endpoint routes" do
    ts = generate(EmptyRouter)

    assert ts =~ "export const routes = {\n} as const"
    assert ts =~ "export type RouteName =\n  never"
  end
end

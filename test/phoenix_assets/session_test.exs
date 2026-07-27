defmodule PhoenixAssets.SessionTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Session}

  defmodule Projection do
    @moduledoc false
    use PhoenixAssets.Session.Fields

    route("/api/session")

    field(:user_id, :string)
    field(:organization_id, :string)
    field(:role, :string, values: ["owner", "admin", "member", "viewer"])
    field(:platform_admin, :boolean)
    field(:impersonated_by, :string, optional: true)
    field(:entitlements, :list)
  end

  defmodule Routeless do
    @moduledoc false
    use PhoenixAssets.Session.Fields

    field(:user_id, :string)
  end

  defmodule Stub do
    @moduledoc false
    def init(opts), do: opts
    def call(conn, _), do: conn
  end

  defmodule Router do
    @moduledoc false
    use Phoenix.Router

    get("/api/session", PhoenixAssets.SessionTest.Stub, :show)
  end

  defp ctx, do: Context.new(Config.load!(otp_app: :my_app), env: :test)

  defp render(module \\ Projection) do
    {:ok, state} = Session.init([session: module], ctx())
    [file] = Session.generated_files(ctx(), state)
    assert file.kind == :session
    IO.iodata_to_binary(file.contents)
  end

  test "renders the interface with wire field names and mapped types" do
    out = render()

    assert out =~ "export interface Session {"
    assert out =~ "  user_id: string\n"
    assert out =~ "  platform_admin: boolean\n"
    assert out =~ "  entitlements: unknown[]\n"
  end

  test "narrows a string field to a literal union when values are declared" do
    assert render() =~ ~s(  role: "owner" | "admin" | "member" | "viewer"\n)
  end

  test "marks an optional field optional rather than nullable" do
    assert render() =~ "  impersonated_by?: string\n"
  end

  test "exports the route and the declared field names" do
    out = render()

    assert out =~ ~s|export const sessionRoute = "/api/session"|

    assert out =~
             ~s|export const sessionFields = ["user_id", "organization_id", "role", | <>
               ~s|"platform_admin", "impersonated_by", "entitlements"] as const|
  end

  test "omits the route export when none is declared" do
    refute render(Routeless) =~ "sessionRoute"
  end

  test "output is deterministic" do
    assert render() == render()
  end

  test "a nil session module contributes no files, entries, or checks" do
    assert Session.generated_files(ctx(), %{module: nil}) == []
    assert Session.graph_entries(ctx(), %{module: nil}) == []
    assert Session.doctor_checks(ctx(), %{module: nil}) == []
  end

  test "graph entry carries the route and the field names" do
    {:ok, state} = Session.init([session: Projection], ctx())
    [entry] = Session.graph_entries(ctx(), state)

    assert entry.kind == :session
    assert entry.data["route"] == "/api/session"
    assert :platform_admin in entry.data["fields"]
  end

  test "doctor check confirms a route that exists in the router" do
    router_ctx = Context.new(Config.load!(otp_app: :my_app, router: Router), env: :test)
    {:ok, state} = Session.init([session: Projection], router_ctx)
    [check] = Session.doctor_checks(router_ctx, state)

    result = check.run.(router_ctx)
    assert result.status == :ok
    assert result.message =~ "/api/session"
  end

  test "doctor check errors on a route the router does not serve" do
    router_ctx = Context.new(Config.load!(otp_app: :my_app, router: Router), env: :test)

    defmodule Elsewhere do
      @moduledoc false
      use PhoenixAssets.Session.Fields

      route("/api/whoami")
      field(:user_id, :string)
    end

    {:ok, state} = Session.init([session: Elsewhere], router_ctx)
    [check] = Session.doctor_checks(router_ctx, state)

    assert check.run.(router_ctx).status == :error
  end

  test "doctor check warns without a router, and without a declared route" do
    {:ok, state} = Session.init([session: Projection], ctx())
    [check] = Session.doctor_checks(ctx(), state)
    assert check.run.(ctx()).status == :warn

    {:ok, routeless} = Session.init([session: Routeless], ctx())
    [routeless_check] = Session.doctor_checks(ctx(), routeless)
    assert routeless_check.run.(ctx()).status == :warn
  end
end

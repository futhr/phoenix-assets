defmodule PhoenixAssets.PubSubTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, PubSub}

  defmodule Topics do
    @moduledoc false
    use PhoenixAssets.PubSub.Topics

    topic(:device, pattern: "device:{id}", events: [updated: "Device", deleted: %{id: :string}])
    topic(:global, pattern: "global", events: [])
  end

  defp render do
    ctx = Context.new(Config.load!(otp_app: :my_app), env: :test)
    {:ok, state} = PubSub.init([topics: Topics], ctx)
    [file] = PubSub.generated_files(ctx, state)
    assert file.kind == :pubsub
    IO.iodata_to_binary(file.contents)
  end

  test "generates topic builders, with and without params" do
    out = render()
    assert out =~ "device: (id: string | number) => `device:${id}`"
    assert out =~ ~s|global: () => "global"|
  end

  test "generates a discriminated event union with typed and inline payloads" do
    out = render()
    assert out =~ ~s|import type { Device } from "$phoenix/types"|
    assert out =~ ~s|{ type: "device:updated"; payload: Device }|
    assert out =~ ~s|{ type: "device:deleted"; payload: { id: string } }|
  end
end

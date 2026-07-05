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

  defmodule EventlessTopics do
    @moduledoc false
    use PhoenixAssets.PubSub.Topics

    topic(:presence, pattern: "presence:{room}", events: [])
  end

  # A hand-rolled topics module (not via the DSL, which rejects a repeated
  # placeholder up front) to exercise the generator's own de-duplication of
  # placeholder params in placeholder_params/1.
  defmodule RepeatedParamTopics do
    @moduledoc false
    def __phoenix_assets_topics__, do: [{:room, [pattern: "room:{id}:{id}", events: []]}]
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

  test "topics without events omit the type import and yield a never event union" do
    ctx = Context.new(Config.load!(otp_app: :my_app), env: :test)
    {:ok, state} = PubSub.init([topics: EventlessTopics], ctx)
    [file] = PubSub.generated_files(ctx, state)
    out = IO.iodata_to_binary(file.contents)

    refute out =~ "$phoenix/types"
    assert out =~ "export type PubSubEvent = never"
    assert out =~ "presence: (room: string | number) => `presence:${room}`"
  end

  test "a pattern that repeats a placeholder collapses to a single builder arg" do
    ctx = Context.new(Config.load!(otp_app: :my_app), env: :test)
    {:ok, state} = PubSub.init([topics: RepeatedParamTopics], ctx)
    out = IO.iodata_to_binary(hd(PubSub.generated_files(ctx, state)).contents)

    # The `id` argument appears once, but both `{id}` positions in the pattern
    # are still interpolated in the returned template literal.
    assert out =~ "room: (id: string | number) => `room:${id}:${id}`"
    refute out =~ "id: string | number, id: string | number"
  end
end

defmodule PhoenixAssets.GeneratedTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Generated, GeneratedFile}

  defmodule FakePlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def generated_files(ctx, _) do
      [
        GeneratedFile.new(
          path: Path.join(ctx.generated_dir, "fake.ts"),
          contents: "export const x = 1\n",
          plugin: :fake,
          kind: :types
        )
      ]
    end
  end

  defmodule EscapingPlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def generated_files(_, _) do
      [GeneratedFile.new(path: "../escape.ts", contents: "nope\n", plugin: :escape, kind: :types)]
    end
  end

  defmodule DuplicatePlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def generated_files(_, _) do
      [GeneratedFile.new(path: "same.ts", contents: "duplicate\n", plugin: :duplicate)]
    end
  end

  defmodule SamePathPlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def generated_files(_, _) do
      [GeneratedFile.new(path: "same.ts", contents: "first\n", plugin: :first)]
    end
  end

  setup do
    tmp = Path.join(System.tmp_dir!(), "pa_gen_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    config = Config.load!(otp_app: :my_app, asset_root: tmp)
    ctx = Context.new(config, env: :test, plugins: [{FakePlugin, []}])
    {:ok, ctx: ctx, tmp: tmp}
  end

  test "writes generated files, then reports them unchanged on a second run", %{
    ctx: ctx,
    tmp: tmp
  } do
    assert {:ok, %{written: ["src/lib/generated/fake.ts"], unchanged: []}} =
             Generated.generate(ctx)

    assert File.read!(Path.join(tmp, "src/lib/generated/fake.ts")) == "export const x = 1\n"

    assert {:ok, %{written: [], unchanged: ["src/lib/generated/fake.ts"]}} =
             Generated.generate(ctx)
  end

  test "check mode reports drift and passes once written", %{ctx: ctx} do
    assert {:error, {:stale, ["src/lib/generated/fake.ts"]}} =
             Generated.generate(ctx, check: true)

    assert {:ok, _} = Generated.generate(ctx)
    assert :ok = Generated.generate(ctx, check: true)
  end

  test "stale?/1 reflects the check result", %{ctx: ctx} do
    assert Generated.stale?(ctx)
    Generated.generate(ctx)
    refute Generated.stale?(ctx)
  end

  test "status/1 splits fresh and stale paths", %{ctx: ctx} do
    assert %{fresh: [], stale: ["src/lib/generated/fake.ts"]} = Generated.status(ctx)
    Generated.generate(ctx)
    assert %{fresh: ["src/lib/generated/fake.ts"], stale: []} = Generated.status(ctx)
  end

  test "output is byte-identical across runs", %{ctx: ctx, tmp: tmp} do
    Generated.generate(ctx)
    first = File.read!(Path.join(tmp, "src/lib/generated/fake.ts"))
    Generated.generate(ctx)
    assert File.read!(Path.join(tmp, "src/lib/generated/fake.ts")) == first
  end

  test "generate/2 refuses a generated path that escapes the asset root", %{tmp: tmp} do
    config = Config.load!(otp_app: :my_app, asset_root: tmp)
    ctx = Context.new(config, env: :test, plugins: [{EscapingPlugin, []}])

    assert_raise ArgumentError, ~r/escapes the asset root/, fn -> Generated.generate(ctx) end
  end

  test "generate/2 rejects two plugins that target the same path", %{tmp: tmp} do
    config = Config.load!(otp_app: :my_app, asset_root: tmp)
    ctx = Context.new(config, plugins: [{SamePathPlugin, []}, {DuplicatePlugin, []}])
    assert {:error, {:duplicate_generated_file, "same.ts"}} = Generated.generate(ctx)
  end

  defmodule PathsPlugin do
    @moduledoc false
    use PhoenixAssets.Plugin
    def init(opts, _), do: {:ok, opts}

    def generated_files(_, opts),
      do: Enum.map(opts[:paths], &GeneratedFile.new(path: &1, contents: "generated"))
  end

  test "validates all destinations before writing any file", %{ctx: ctx, tmp: tmp} do
    ctx = %{ctx | plugins: [{PathsPlugin, paths: ["a.ts", "z/../../escape.ts"]}]}
    assert_raise ArgumentError, fn -> Generated.generate(ctx) end
    refute File.exists?(Path.join(tmp, "a.ts"))
  end

  test "rejects normalized duplicate destinations before writing", %{ctx: ctx, tmp: tmp} do
    ctx = %{ctx | plugins: [{PathsPlugin, paths: ["a.ts", "nested/../a.ts"]}]}
    assert {:error, {:duplicate_generated_file, _}} = Generated.generate(ctx)
    refute File.exists?(Path.join(tmp, "a.ts"))
  end

  test "generation, status, and cleanup cannot follow symlinks", %{ctx: ctx, tmp: tmp} do
    outside = tmp <> "_outside"
    File.mkdir_p!(outside)
    on_exit(fn -> File.rm_rf!(outside) end)
    target = Path.join(outside, "contract.ts")
    File.write!(target, "generated")
    File.ln_s!(outside, Path.join(tmp, "linked"))
    ctx = %{ctx | plugins: [{PathsPlugin, paths: ["linked/contract.ts"]}]}

    for operation <- [&Generated.generate/1, &Generated.status/1, &Generated.clean/1] do
      assert_raise ArgumentError, ~r/symlink/, fn -> operation.(ctx) end
    end

    assert File.read!(target) == "generated"
  end

end

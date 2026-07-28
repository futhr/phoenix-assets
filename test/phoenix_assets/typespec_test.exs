defmodule PhoenixAssets.TypespecTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Generated, Typespec}
  alias PhoenixAssets.Test.TypespecFixture, as: Source

  defp ctx(stack \\ []) do
    tmp = Path.join(System.tmp_dir!(), "ts_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    config = Config.load!(otp_app: :my_app, asset_root: tmp, stack: stack)
    Context.new(config, env: :test, plugins: [{Typespec, []}])
  end

  defp declaration,
    do: [typespecs: [[source: Source, output: "stream.ts", root: :t, root_name: "StreamPart"]]]

  test "generates nothing when no typespecs are declared" do
    {:ok, state} = Typespec.init([], ctx())

    assert Typespec.generated_files(ctx(), state) == []
    assert Typespec.graph_entries(ctx(), state) == []
  end

  test "renders a declared typespec into the generated directory" do
    context = ctx(declaration())
    {:ok, state} = Typespec.init([], context)

    assert [file] = Typespec.generated_files(context, state)
    assert file.kind == :typespec
    assert Path.basename(file.path) == "stream.ts"

    contents = IO.iodata_to_binary(file.contents)
    assert contents =~ "export type StreamPart"
    assert contents =~ "Do not edit"
  end

  test "reads declarations from the :stack config as well as preset options" do
    context = ctx()
    {:ok, state} = Typespec.init(declaration(), context)

    assert [_] = Typespec.generated_files(context, state)
  end

  test "contributes one graph entry per declared contract" do
    context = ctx(declaration())
    {:ok, state} = Typespec.init([], context)

    assert [entry] = Typespec.graph_entries(context, state)
    assert entry.kind == :typespec
    assert entry.key == "stream.ts"
  end

  describe "configuration errors surface at init, not as a missing file" do
    test "rejects an entry without a source" do
      assert_raise ArgumentError, ~r/missing `source:`/, fn ->
        Typespec.init([typespecs: [[output: "x.ts"]]], ctx())
      end
    end

    test "rejects an entry without an output" do
      assert_raise ArgumentError, ~r/missing `output:`/, fn ->
        Typespec.init([typespecs: [[source: Source]]], ctx())
      end
    end

    test "rejects a source that is not a module" do
      assert_raise ArgumentError, ~r/must be a module/, fn ->
        Typespec.init([typespecs: [[source: "Source", output: "x.ts"]]], ctx())
      end
    end

    test "rejects an entry that is not a keyword list" do
      assert_raise ArgumentError, ~r/must be a keyword list/, fn ->
        Typespec.init([typespecs: [:nope]], ctx())
      end
    end

    test "explains a source module that declares no typespecs" do
      context = ctx(typespecs: [[source: Source.Untyped, output: "x.ts"]])
      {:ok, state} = Typespec.init([], context)

      assert_raise ArgumentError, ~r/no typespecs to render/, fn ->
        Typespec.generated_files(context, state)
      end
    end
  end

  describe "the doctor" do
    test "passes for a module that declares typespecs" do
      context = ctx(declaration())
      {:ok, state} = Typespec.init([], context)

      assert [check] = Typespec.doctor_checks(context, state)
      assert check.run.(context).status == :ok
    end

    test "errors for a module that is not loaded" do
      context = ctx(typespecs: [[source: NoSuchModule.Nope, output: "x.ts"]])
      {:ok, state} = Typespec.init([], context)

      assert [check] = Typespec.doctor_checks(context, state)
      assert check.run.(context).status == :error
    end
  end

  # The whole reason this is a plugin: a host calling the renderer directly got
  # none of the pipeline's guarantees.
  describe "pipeline integration" do
    test "is content-gated, so a second run writes nothing" do
      context = ctx(declaration())

      assert {:ok, %{written: [path], unchanged: []}} = Generated.generate(context)
      assert Path.basename(path) == "stream.ts"
      assert {:ok, %{written: [], unchanged: [^path]}} = Generated.generate(context)
    end

    test "is covered by the --check drift gate" do
      context = ctx(declaration())

      assert {:error, {:stale, [_]}} = Generated.generate(context, check: true)
      assert {:ok, _} = Generated.generate(context)
      assert :ok = Generated.generate(context, check: true)
    end
  end
end

defmodule PhoenixAssets.LocalizeTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Localize}

  defmodule Backend do
    @moduledoc false
    use Gettext.Backend, otp_app: :phoenix_assets, default_locale: "en"
  end

  defp ctx, do: Context.new(Config.load!(otp_app: :my_app), env: :test)

  test "generates the locale union from an explicit list" do
    {:ok, state} = Localize.init([locales: ~w(en sv), default_locale: "en"], ctx())
    [file] = Localize.generated_files(ctx(), state)
    out = IO.iodata_to_binary(file.contents)

    assert file.kind == :locales
    assert out =~ ~s|export const locales = ["en","sv"] as const|
    assert out =~ "export type Locale = (typeof locales)[number]"
    assert out =~ ~s|export const defaultLocale: Locale = "en"|
  end

  test "contributes one sorted, de-duplicated graph entry per locale" do
    {:ok, state} = Localize.init([locales: ~w(sv en en)], ctx())
    entries = Localize.graph_entries(ctx(), state)

    assert Enum.map(entries, & &1.key) == ["en", "sv"]
    assert Enum.all?(entries, &(&1.kind == :locale))
  end

  test "scans a gettext directory for locale subdirectories, ignoring stray files" do
    dir = Path.join(System.tmp_dir!(), "gx_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(dir, "en/LC_MESSAGES"))
    File.mkdir_p!(Path.join(dir, "sv/LC_MESSAGES"))
    File.write!(Path.join(dir, "default.pot"), "")
    on_exit(fn -> File.rm_rf!(dir) end)

    {:ok, state} = Localize.init([gettext_dir: dir], ctx())
    [file] = Localize.generated_files(ctx(), state)
    out = IO.iodata_to_binary(file.contents)

    assert out =~ ~s|export const locales = ["en","sv"] as const|
    assert out =~ ~s|export const defaultLocale: Locale = "en"|
  end

  test "yields no locales when the scan root does not exist" do
    {:ok, state} =
      Localize.init([gettext_dir: "/no/such/gettext-#{System.unique_integer()}"], ctx())

    out = IO.iodata_to_binary(hd(Localize.generated_files(ctx(), state)).contents)

    assert out =~ ~s|export const locales = [] as const|
    assert out =~ "export const defaultLocale: Locale | null = null"
  end

  test "ignores dot-directories when scanning gettext" do
    dir = Path.join(System.tmp_dir!(), "gd_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(dir, "en/LC_MESSAGES"))
    File.mkdir_p!(Path.join(dir, ".cache"))
    on_exit(fn -> File.rm_rf!(dir) end)

    {:ok, state} = Localize.init([gettext_dir: dir], ctx())
    out = IO.iodata_to_binary(hd(Localize.generated_files(ctx(), state)).contents)

    assert out =~ ~s|export const locales = ["en"] as const|
  end

  test "defaultLocale prefers the Gettext backend's configured default" do
    {:ok, state} =
      Localize.init(
        [locales: ~w(de en sv), gettext_backend: PhoenixAssets.LocalizeTest.Backend],
        ctx()
      )

    out = IO.iodata_to_binary(hd(Localize.generated_files(ctx(), state)).contents)

    # Alphabetical fallback would pick "de"; the backend says "en".
    assert out =~ ~s|export const defaultLocale: Locale = "en"|
  end

  test "zero locales raises instead of emitting a `Locale = never` union" do
    {:ok, state} = Localize.init([locales: []], ctx())

    error =
      assert_raise ArgumentError, fn -> Localize.generated_files(ctx(), state) end

    assert Exception.message(error) =~ "no locales found"
  end

  test "a default_locale outside the locale list raises instead of emitting broken TS" do
    {:ok, state} = Localize.init([locales: ~w(en sv), default_locale: "de"], ctx())

    error =
      assert_raise ArgumentError, fn -> Localize.generated_files(ctx(), state) end

    assert Exception.message(error) =~ ~s(default locale "de" is not one of)
  end

  test "an explicit default_locale overrides the backend" do
    {:ok, state} =
      Localize.init(
        [
          locales: ~w(de en sv),
          default_locale: "sv",
          gettext_backend: PhoenixAssets.LocalizeTest.Backend
        ],
        ctx()
      )

    out = IO.iodata_to_binary(hd(Localize.generated_files(ctx(), state)).contents)
    assert out =~ ~s|export const defaultLocale: Locale = "sv"|
  end

  describe "configuring without a preset" do
    defp stack_ctx(stack) do
      Context.new(Config.load!(otp_app: :my_app, stack: stack), env: :test)
    end

    test "reads locales and default_locale from the :stack config" do
      ctx = stack_ctx(locales: ~w(sv en no da), default_locale: "sv")
      {:ok, state} = Localize.init([], ctx)

      out = IO.iodata_to_binary(hd(Localize.generated_files(ctx, state)).contents)

      assert out =~ ~s|export const locales = ["da","en","no","sv"] as const|
      assert out =~ ~s|export const defaultLocale: Locale = "sv"|
    end

    test "a preset's integration options win over the :stack config" do
      ctx = stack_ctx(locales: ~w(sv en), default_locale: "sv")
      {:ok, state} = Localize.init([locales: ~w(en), default_locale: "en"], ctx)

      out = IO.iodata_to_binary(hd(Localize.generated_files(ctx, state)).contents)

      assert out =~ ~s|export const locales = ["en"] as const|
    end

    test "emits a display and native name for every locale" do
      ctx = stack_ctx(locales: ~w(sv en ja), default_locale: "en")
      {:ok, state} = Localize.init([], ctx)

      out = IO.iodata_to_binary(hd(Localize.generated_files(ctx, state)).contents)

      assert out =~ ~s|"sv":{"name":"Swedish","nativeName":"Svenska"}|
      assert out =~ ~s|"ja":{"name":"Japanese","nativeName":"日本語"}|
      assert out =~ "export const localeNames: Record<Locale,"
    end

    test "resolves a regional locale through its primary subtag" do
      ctx = stack_ctx(locales: ~w(pt-BR), default_locale: "pt-BR")
      {:ok, state} = Localize.init([], ctx)

      out = IO.iodata_to_binary(hd(Localize.generated_files(ctx, state)).contents)

      assert out =~ ~s|"pt-BR":{"name":"Portuguese","nativeName":"Português"}|
    end

    # The built-in table covers the languages the fleet ships, not all of ISO
    # 639. An unknown code must still produce a usable entry.
    test "falls back to the code itself for an unknown language" do
      ctx = stack_ctx(locales: ~w(zz), default_locale: "zz")
      {:ok, state} = Localize.init([], ctx)

      out = IO.iodata_to_binary(hd(Localize.generated_files(ctx, state)).contents)

      assert out =~ ~s|"zz":{"name":"zz","nativeName":"zz"}|
    end

    test "accepts host-supplied names for locales the table does not know" do
      ctx =
        stack_ctx(
          locales: ~w(zz),
          default_locale: "zz",
          locale_names: %{"zz" => %{name: "Zedish", native_name: "Zedska"}}
        )

      {:ok, state} = Localize.init([], ctx)
      out = IO.iodata_to_binary(hd(Localize.generated_files(ctx, state)).contents)

      assert out =~ ~s|"zz":{"name":"Zedish","nativeName":"Zedska"}|
    end

    # `locales: []` is a misconfiguration worth raising on, but an empty
    # `:stack` must not be mistaken for one -- the key has to stay absent.
    test "an empty :stack still falls back to scanning priv/gettext" do
      ctx = stack_ctx([])
      {:ok, state} = Localize.init([], ctx)

      assert [file] = Localize.generated_files(ctx, state)
      assert file.kind == :locales
    end
  end
end

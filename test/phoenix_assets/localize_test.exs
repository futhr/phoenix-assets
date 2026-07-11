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
end

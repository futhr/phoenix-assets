%Doctor.Config{
  # 100% documentation and typespecs across the board. The ignored modules expose
  # their public accessor through a `__before_compile__` quote -- doctor counts that
  # compile-time-generated `def` but cannot see its `@doc`/`@spec`, so it under-reports.
  # All of them are fully documented (moduledoc + macro `@doc`); the behaviour
  # callbacks elsewhere are marked `@impl` and skipped, as they should be.
  exception_moduledoc_required: true,
  failed: false,
  ignore_modules: [
    PhoenixAssets.Commands.Definitions,
    PhoenixAssets.Electric.Shapes,
    PhoenixAssets.Plugin,
    PhoenixAssets.Preset,
    PhoenixAssets.PubSub.Topics,
    PhoenixAssets.Session.Fields,
    PhoenixAssets.Types.Schema
  ],
  ignore_paths: [~r(^test/)],
  min_module_doc_coverage: 100,
  min_module_spec_coverage: 100,
  min_overall_doc_coverage: 100,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 100,
  raise: true,
  reporter: Doctor.Reporters.Summary,
  struct_type_spec_required: true,
  umbrella: false
}

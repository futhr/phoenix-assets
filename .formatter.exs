[
  inputs: ["{mix,.formatter,.check,.doctor}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 98,
  # The Ash fixtures under test/support use Ash's no-parens DSL style.
  locals_without_parens: [attribute: 2, attribute: 3, uuid_primary_key: 1, uuid_primary_key: 2],
  # Picked up by host apps via `import_deps: [:phoenix_assets]`, so their
  # formatter leaves the declaration DSLs alone instead of parenthesising them.
  export: [
    locals_without_parens: [
      command: 2,
      field: 2,
      field: 3,
      integration: 1,
      integration: 2,
      route: 1,
      shape: 2,
      topic: 2,
      type: 2
    ]
  ]
]

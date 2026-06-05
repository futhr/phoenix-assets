[
  inputs: ["{mix,.formatter,.check,.doctor}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 98,
  # The Ash fixtures under test/support use Ash's no-parens DSL style.
  locals_without_parens: [attribute: 2, attribute: 3, uuid_primary_key: 1, uuid_primary_key: 2]
]

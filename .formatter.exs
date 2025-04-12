# Used by "mix format"
[
  # Remove :ex_unit since it's not an external dependency
  import_deps: [],
  inputs: [
    "mix.exs",
    "config/*.exs",
    "lib/**/*.ex",
    "test/**/*.exs"
  ],
  line_length: 100,
  locals_without_parens: [],
  export: []
]

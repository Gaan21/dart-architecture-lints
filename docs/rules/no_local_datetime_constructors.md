<!-- example-scope: isolated no_local_datetime_constructors -->

> **Example contract: `no_local_datetime_constructors` only.** Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md) for executed whole-profile acceptance.

# no_local_datetime_constructors

Discourages direct clocks and local instant construction. Default behavior keeps
checks for `DateTime.now()`, unnamed constructors, epoch constructors without
`isUtc: true`, and ambiguous parse expressions. An injected clock enables
deterministic tests; selecting this rule does not supply a clock implementation.

Use `civil_date_globs` for explicit civil-calendar files and `clock_globs` for
clock adapters. These opt-in file scopes are separate: allowing calendar
construction does not permit direct clocks, and allowing clocks does not permit
all local constructors. No automatic test/example-directory exemption exists.
Use `exclude_globs` only when intentionally excluding a file from this rule.

See [configuration](../configuration.md) for the installed custom_lint option
syntax and for how this rule differs from data-layer UTC representation checks.

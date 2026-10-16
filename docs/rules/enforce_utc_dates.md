<!-- example-scope: isolated enforce_utc_dates -->

> **Example contract: `enforce_utc_dates` only.** Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md) for executed whole-profile acceptance.

# enforce_utc_dates

Requires UTC representations for instant construction in the existing data-layer
path scope. See [time scopes](../configuration.md) for exact include filters and
explicit civil-calendar/clock exceptions. Defaults preserve instant protection.

`DateTime.utc(...)`, epoch constructors with `isUtc: true`, directly chained
`toUtc()`, and ISO parse literals with `Z` or an explicit numeric offset are
accepted. Ambiguous parse strings are reported. Epoch getters such as
`millisecondsSinceEpoch` represent the same instant regardless of zone; they do
not require `toUtc()`.

These are construction-site checks, not dataflow proof that arbitrary DateTime
variables are UTC. Civil calendar dates should be modeled separately and their
unnamed constructors allowed only in explicitly reviewed `civil_date_globs`.
Civil exceptions do not permit clocks or ambiguous parsing.

The separate organization-zone display, civil/instant mix and device-local
presentation rules remain selected by the architecture and legacy samples.

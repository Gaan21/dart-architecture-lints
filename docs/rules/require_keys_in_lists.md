<!-- example-scope: isolated require_keys_in_lists -->

> **Example contract: `require_keys_in_lists` only.** Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md) for executed whole-profile acceptance.

# require_keys_in_lists

Selected by default and by the architecture sample. It checks directly returned
widget constructions in expression-bodied `ListView.builder` and
`GridView.builder` callbacks. Block callbacks, helper returns and conditional
expressions are outside the current analysis.

When data can be inserted, removed or reordered, prefer a stable `ValueKey` using
item identity. `ObjectKey` is useful when object identity itself is stable.
An index is not stable identity for reordered items. Do not create a new
`UniqueKey` every build: it discards element continuity.

Keys help preserve state identity; they do not guarantee fewer rebuilds or better
performance. The rule checks presence, not uniqueness or stability of a key, and
does not prove a list needs keys. Tests use original resolved widget stand-ins to
check missing/present keys without requiring Flutter at test time. They are not
Flutter rendering or state-retention tests.

See [selection and UI limits](../configuration.md).

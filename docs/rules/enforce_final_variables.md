<!-- example-scope: isolated enforce_final_variables -->

> **Example contract: `enforce_final_variables` only.** Any Dart fences are isolated sketches, not compiled whole-profile fixtures. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md) for executed acceptance.

# enforce_final_variables

Reports local `var` bindings with no resolved writes in their enclosing function
body. Direct and compound assignments, increments and captured writes in nested
closures keep a binding mutable. Same-named declarations resolve independently.
The diagnostic ID remains `enforce_final_variables`.

Loop declarations retain their existing exception. Fields and top-level bindings
are not inferred immutable by a one-file scan; external code may write them.
For a multi-variable declaration, any immutable binding can trigger the shared
`var` diagnostic; split mutable and immutable bindings before applying `final`.

`final` protects the binding, not deep object immutability. A reassigned local is
valid and must not be converted mechanically to `final`. In the selective typing
profile an obvious immutable local may be inferred; legacy strict typing still
requires its written type.

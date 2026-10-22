<!-- example-scope: isolated require_explicit_types -->

> **Example contract: `require_explicit_types` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# require_explicit_types

**Default severity**: info. Enabled by default.

## What it detects

Default `policy: strict`: every field declaration, local variable declaration and `for`/`for-in` loop variable (statements and collection elements) without a type annotation. `policy: selective`: public fields and top-level variables, public method/getter and top-level function return types (setters excluded), simple parameters of public methods, constructors and top-level functions; locals only when inferred as `dynamic` or matching `local_names`. Private classes and private declarations are excluded in selective mode.

## Why

Explicit types at selected boundaries keep APIs readable and stop accidental `dynamic` or widened types.

## Example

```dart
// BAD
class Cart {
  final items = <Item>[];
}
```

```dart
// GOOD
class Cart {
  final List<Item> items = <Item>[];
}
```

## Disable if

Your style relies on inference (for example the upstream `omit_local_variable_types`), or use `policy: selective` to keep only boundary annotations.

## Options

Sibling keys: `policy` (`strict` default, or `selective`; other values throw) and `local_names` (wildcard patterns of local names that need annotations in selective mode). Example: `- require_explicit_types: true` then `  policy: selective` on the next line.

## Limits

- Strict mode adds no signature checks; selective mode does not check loop variables.
- Initializing and super formals (`this.x`, `super.x`) are not simple parameters and inherit their types.
- Anonymous callbacks and local functions are not public API; extension and mixin members are judged by name only.

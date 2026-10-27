<!-- example-scope: isolated require_explicit_types -->

> **Example contract: `require_explicit_types` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# require_explicit_types

**Default severity**: info. Enabled by default.

## What it detects

Every field declaration, local variable declaration and `for`/`for-in` loop variable (statements and collection elements) without a type annotation (the `strict` policy).

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

Your style relies on inference (for example the upstream `omit_local_variable_types`).

## Options

Fixed since 0.1.0 (the analyzer plugin API has no rule options): the `strict` policy, without extra local-name patterns. The former `selective` policy is not available.

## Limits

- No signature checks: return types and parameters are not required.

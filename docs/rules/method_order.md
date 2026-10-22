<!-- example-scope: isolated method_order -->

> **Example contract: `method_order` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# method_order

**Default severity**: info. Enabled by default.

## What it detects

Within each class, methods must appear as: getters and setters, then `@override` methods, then other public methods, then private methods. A member that appears after a later group is reported.

## Why

A predictable member order makes classes faster to scan and review.

## Example

```dart
// BAD
class Counter {
  void _reset() {}
  void increment() {}
}
```

```dart
// GOOD
class Counter {
  int get value => _value;
  @override
  String toString() => "$_value";
  void increment() {}
  void _reset() {}
  int _value = 0;
}
```

## Disable if

Your style guide orders members differently (for example by feature).

## Options

None.

## Limits

- Only method declarations in classes; fields, constructors, mixins, enums and extensions are not ordered.
- Getters and setters count as the first group even when annotated `@override`.

<!-- example-scope: isolated one_class_per_file -->

> **Example contract: `one_class_per_file` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# one_class_per_file

**Default severity**: info. Enabled by default.

## What it detects

Files with more than one public class, enum or mixin. The largest class (by lines) is the main type; other public types are reported unless they are classes that directly extend the main class. Without any class, every type after the first is reported.

## Why

One primary type per file keeps files small and makes types easy to locate.

## Example

```dart
// BAD
class Order {}
enum OrderStatus { open, closed }
```

```dart
// GOOD
sealed class OrderState {}
class OrderOpen extends OrderState {}
class OrderClosed extends OrderState {}
```

## Disable if

Your style keeps related types (enums, small value types, sealed families) together.

## Options

None.

## Limits

- Private types, typedefs, extensions and extension types are not counted.
- Subclasses must extend the main class directly; implementers and indirect subclasses are reported.

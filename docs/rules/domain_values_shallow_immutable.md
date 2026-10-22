<!-- example-scope: isolated domain_values_shallow_immutable -->

> **Example contract: `domain_values_shallow_immutable` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# domain_values_shallow_immutable

**Default severity**: info. Enabled by default.

## What it detects

In files whose URI path contains `/domain/entities/` or `/domain/value_objects/`, in classes and mixins: non-final, non-const instance fields (including private, `abstract`, `external` and `covariant` ones), public `late final` fields without an initializer (they expose a setter) and public instance setters. Classes annotated `@freezed`/`@Freezed` (also with an import prefix) are skipped.

## Why

Immutable values avoid shared-state surprises; changes create a new instance. This is generator-independent and accepts plain classes or Freezed.

## Example

```dart
// BAD
class Order {
  Order(this.id, this.status);
  final String id;
  OrderStatus status;
  set note(String value) {}
}
```

```dart
// GOOD
class Order {
  const Order({required this.id, required this.status});
  final String id;
  final OrderStatus status;
  Order withStatus(OrderStatus next) => Order(id: id, status: next);
}
```

## Disable if

Your domain model uses mutable entities deliberately.

## Options

None.

## Limits

- Shallow: `final List<T>` fields and mutable referenced objects pass, because the declared type cannot show runtime unmodifiability.
- Static fields, `late final` fields with an initializer, private setters, enums, extension types and generated code are not reported.
- Freezed classes are accepted by annotation spelling. Upstream `@immutable` (`package:meta`) is an alternative analyzer check.

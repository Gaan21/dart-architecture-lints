<!-- example-scope: isolated domain_entities_must_use_freezed -->

> **Example contract: `domain_entities_must_use_freezed` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# domain_entities_must_use_freezed

**Default severity**: info. Enabled by default.

## What it detects

Concrete (non-`abstract`), public classes in files whose URI path contains `/domain/entities/` or `/domain/value_objects/` without an annotation spelled `freezed` or `Freezed`.

## Why

In projects that adopted Freezed, the generator supplies equality, `copyWith` and immutable fields consistently. Freezed is a convention, not a universal requirement: `domain_values_shallow_immutable` checks immutability without a generator.

## Example

```dart
// BAD
class User {
  const User({required this.id});
  final String id;
}
```

```dart
// GOOD
@freezed
class User with _$User {
  const factory User({required String id}) = _User;
}
```

## Disable if

The project does not use Freezed for domain values (plain immutable classes or another generator). The rule does not read `pubspec.yaml`, so a dependency neither enables nor disables it.

## Options

None.

## Limits

- Annotation spelling only: the generated part, equality, `copyWith` and unmodifiable collections are not checked.
- `@unfreezed` and mutable collection options are not detected; an annotation does not prove deep immutability.

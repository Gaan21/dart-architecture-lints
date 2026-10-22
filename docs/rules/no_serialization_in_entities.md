<!-- example-scope: isolated no_serialization_in_entities -->

> **Example contract: `no_serialization_in_entities` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_serialization_in_entities

**Default severity**: info. Enabled by default.

## What it detects

In files whose URI path contains `/domain/entities/` or `/domain/value_objects/`: class annotations named `JsonSerializable`, `jsonSerializable` or `JsonKey`, methods named `fromJson` or `toJson`, and constructors named `fromJson`.

## Why

Wire formats change for transport reasons. Keeping codecs in data-layer models stops them from reshaping domain types.

## Example

```dart
// BAD
class User {
  const User(this.id);
  factory User.fromJson(Map<String, Object?> json) => User(json['id'] as String);
  final String id;
}
```

```dart
// GOOD
class User {
  const User(this.id);
  final String id;
}
// lib/data/models/user_model.dart owns fromJson/toJson and a mapper.
```

## Disable if

The project deliberately serializes domain types directly and has no separate data models.

## Options

None.

## Limits

- Matches annotation and member names only; codecs in extensions, static helpers or generated parts are not checked.
- Freezed `fromJson` factories declared on entity classes are reported because they are constructors named `fromJson`.

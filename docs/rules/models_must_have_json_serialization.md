<!-- example-scope: isolated models_must_have_json_serialization -->

> **Example contract: `models_must_have_json_serialization` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# models_must_have_json_serialization

**Default severity**: info. Enabled by default.

## What it detects

Concrete public classes in files whose URI path contains `/data/models/` that have neither an annotation named `JsonSerializable`, `jsonSerializable`, `freezed` or `Freezed`, nor both a constructor named `fromJson` and a method named `toJson`.

## Why

Data models are the serialization boundary; a model without a codec usually means serialization leaked elsewhere.

## Example

```dart
// BAD
class UserModel {
  const UserModel(this.id);
  final String id;
}
```

```dart
// GOOD
class UserModel {
  const UserModel(this.id);
  factory UserModel.fromJson(Map<String, Object?> json) => UserModel(json['id'] as String);
  final String id;
  Map<String, Object?> toJson() => {'id': id};
}
```

## Disable if

Your models use another codec (protobuf, a database mapper), or the folder holds non-serialized types.

## Options

None.

## Limits

- Annotation and member names only: it does not check that codecs work or round-trip.
- A Freezed annotation satisfies the rule even without a `fromJson` factory.

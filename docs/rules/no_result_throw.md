<!-- example-scope: isolated no_result_throw -->

> **Example contract: `no_result_throw` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_result_throw

**Default severity**: info. Enabled by default.

## What it detects

In classes whose name contains `UseCase` or `Repository`, every method, getter and setter body (public or private, including closures): `throw` and `rethrow` expressions, except those lexically inside the `try` block of a try statement in the same function body with a clause that catches them (no `on` type, `on Object`, or an `on` type that is a supertype of the thrown static type; for `rethrow`, the type its own clause caught). Closures are a boundary.

## Why

Use cases and repositories report failures as `Result` values; an escaping exception bypasses that contract.

## Example

```dart
// BAD
Future<Result<void>> execute(Draft draft) async {
  if (draft.title.isEmpty) throw ValidationException();
  try {
    return Result.ok(await _repository.save(draft));
  } catch (error) {
    rethrow;
  }
}
```

```dart
// GOOD
Future<Result<void>> execute(Draft draft) async {
  try {
    if (draft.title.isEmpty) throw ValidationException();
    return Result.ok(await _repository.save(draft));
  } on ValidationException catch (error) {
    return Result.error(error);
  }
}
```

## Disable if

Your project lets these classes throw, for example when a shared guard converts exceptions.

## Options

None.

## Limits

- Lexical only: it does not prove that called code cannot throw.
- The name match is broad (`BaseUseCase`, `RepositoryFactory`); a guard base that rethrows defects needs a reasoned `ignore`.
- Constructors, field initializers, mixins and extensions are not checked; programmer-defect throws are not distinguished.

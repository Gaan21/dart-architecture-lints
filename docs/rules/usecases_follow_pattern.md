<!-- example-scope: isolated usecases_follow_pattern -->

> **Example contract: `usecases_follow_pattern` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# usecases_follow_pattern

**Default severity**: info. Enabled by default.

**WorkTracker-specific**: fixed WorkTracker use-case entry point `execute()` returning `Result`. Disable outside WorkTracker.

## What it detects

Concrete classes whose name ends with `UseCase` that do not declare a public `execute` method whose annotated return type is spelled `Result<...>` or `Future<Result<...>>`. Only the first `execute` method declared in the class is considered.

## Why

One entry point with a typed outcome makes use cases interchangeable for callers and keeps failures explicit.

## Example

```dart
// BAD
class GetUserUseCase {
  Future<User> run(String id) => repository.getUser(id);
}
```

```dart
// GOOD
class GetUserUseCase {
  Future<Result<User>> execute(String id) => repository.getUser(id);
}
```

## Disable if

In any project outside WorkTracker that does not adopt the same convention. Your project names the entry point differently (for example `call`) or does not use a Result type.

## Options

None.

## Limits

- Spelling-based: unannotated returns, `FutureOr<Result<T>>`, typedef aliases and a bare `Result` without type arguments are reported.
- An `execute` inherited from a base class does not count; the class must declare it.
- Applies in any folder; abstract classes are skipped.

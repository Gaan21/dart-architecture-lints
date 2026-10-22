<!-- example-scope: isolated usecases_extend_base_usecase -->

> **Example contract: `usecases_extend_base_usecase` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# usecases_extend_base_usecase

**Default severity**: info. Enabled by default.

**WorkTracker-specific**: fixed `BaseUseCase` base class and `/domain/useCases/` folder. Disable outside WorkTracker.

## What it detects

Concrete public classes whose name ends with `UseCase`, in files whose URI path contains `/domain/useCases/`, whose direct superclass is not spelled `BaseUseCase`.

## Why

The project base class centralizes guarded conversion of failures into `Result`, so each use case gets the same error handling.

## Example

```dart
// BAD
class GetUserUseCase {
  Future<Result<User>> execute(String id) => repository.getUser(id);
}
```

```dart
// GOOD
class GetUserUseCase extends BaseUseCase<User, String> {
  @override
  Future<Result<User>> execute(String id) => executeGuard(() => repository.getUser(id));
}
```

## Disable if

In any project outside WorkTracker that does not adopt the same convention. Your project has no `BaseUseCase`, shares that behavior by composition, or has no use-case layer.

## Options

None.

## Limits

- Direct superclass name only: indirect bases (`extends MyBase` where `MyBase extends BaseUseCase`) are reported.
- Folders spelled other than `/domain/useCases/` are not checked.

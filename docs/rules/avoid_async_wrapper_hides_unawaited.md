<!-- example-scope: isolated avoid_async_wrapper_hides_unawaited -->

> **Example contract: `avoid_async_wrapper_hides_unawaited` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# avoid_async_wrapper_hides_unawaited

**Default severity**: info. Enabled by default.

**WorkTracker-specific**: guards the WorkTracker `avoid_unawaited` convention against single-await wrappers. Disable outside WorkTracker.

## What it detects

`scheduleMicrotask(...)`, `Timer.run(...)` and unnamed `Future(...)` calls whose only argument is an `async` block callback containing exactly one statement: `await expr;` or `return await expr;`.

## Why

Such a wrapper starts a future nobody awaits, like `unawaited(expr)`, but hides it from `avoid_unawaited` and its justification requirement.

## Example

```dart
// BAD
scheduleMicrotask(() async {
  await syncPending();
});
```

```dart
// GOOD
// unawaited-ok: prefetch-noncritical - warm cache, errors logged inside
unawaited(syncPending());
```

## Disable if

In any project outside WorkTracker that does not adopt the same convention. You do not enforce `avoid_unawaited`, so there is nothing to bypass.

## Options

None.

## Limits

- Expression-bodied callbacks (`() async => await x`) and multi-statement callbacks are not reported.
- Other schedulers (`Future.microtask`, `Future.delayed`, `then`) are not checked.

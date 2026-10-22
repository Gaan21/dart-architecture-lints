<!-- example-scope: isolated avoid_scattered_401_handling -->

> **Example contract: `avoid_scattered_401_handling` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# avoid_scattered_401_handling

**Default severity**: info. Enabled by default.

**WorkTracker-specific**: fixed allowed class names `AuthInterceptor` and `AuthService`. Disable outside WorkTracker.

## What it detects

Equality comparisons between an expression named `statusCode` (identifier, property or prefixed) and the integer literal `401`, in either order, outside classes named `AuthInterceptor` or `AuthService`. Files with `/test/` in their path are skipped.

## Why

Unauthorized handling (refresh, logout, redirect) should have one owner; scattered branches drift and double-handle the same response.

## Example

```dart
// BAD
if (response.statusCode == 401) {
  await session.logout();
}
```

```dart
// GOOD
class AuthInterceptor {
  bool isUnauthorized(int statusCode) => statusCode == 401;
}
```

## Disable if

In any project outside WorkTracker that does not adopt the same convention. Your central auth handler has a different class name, or the project has no centralized auth boundary.

## Options

None. The allowed class names are fixed.

## Limits

- Only `==` with the literal `401`; constants (`HttpStatus.unauthorized`), `!=`, switch cases and other status names are not detected.
- Top-level functions and extensions are never allowed locations.

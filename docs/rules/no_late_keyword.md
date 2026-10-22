<!-- example-scope: isolated no_late_keyword -->

> **Example contract: `no_late_keyword` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_late_keyword

**Default severity**: info. Enabled by default.

## What it detects

Every `late` variable declaration (fields, top-level and locals). Allowed: `late final` declarations whose annotated type name contains `getit`, `locator`, `servicelocator`, `container`, `injector`, `provider` or `resolver`, or that are inside a class whose name contains `container`, `locator`, `injector`, `servicecontainer`, `dependencycontainer` or `di` (case-insensitive). Files with any path segment containing `test` are skipped.

## Why

A `late` variable read before assignment throws at runtime, and initialization order becomes implicit.

## Example

```dart
// BAD
class Profile {
  late String name;
}
```

```dart
// GOOD
class Profile {
  Profile(this.name);
  final String name;
}
```

## Disable if

Your team uses `late` (including lazy `late final x = ...` initializers) where initialization is guaranteed and reviewed.

## Options

None.

## Limits

- Lazy initializers (`late final x = compute();`) are reported unless they match the DI exceptions.
- The DI exception is a name heuristic: any class name containing `di` (for example `Audio`) qualifies.

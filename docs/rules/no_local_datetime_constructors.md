<!-- example-scope: isolated no_local_datetime_constructors -->

> **Example contract: `no_local_datetime_constructors` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_local_datetime_constructors

**Default severity**: info. Enabled by default.

## What it detects

In files matching the scope: `dart:core` `DateTime.now()`, the unnamed `DateTime(...)` constructor, `fromMillisecondsSinceEpoch`/`fromMicrosecondsSinceEpoch` without a literal `isUtc: true`, and `DateTime.parse(...)` unless the argument is a string literal with `Z` or an offset, or the result is immediately followed by `.toUtc()`. `DateTime.utc(...)` is allowed.

## Why

Local construction depends on the device zone and the real clock. UTC values and an injected clock keep instants consistent and testable.

## Example

```dart
// BAD
final DateTime startedAt = DateTime.now();
```

```dart
// GOOD
final DateTime startedAt = clock.now().toUtc();
```

## Disable if

Your project accepts device-local time and does not inject a clock.

## Options

Sibling keys: `include_globs` (default `["**"]`), `exclude_globs`, `civil_date_globs` (allows the unnamed `DateTime(year, ...)` constructor) and `clock_globs` (allows `DateTime.now()` in clock adapters).

## Limits

- Implemented in `lib/no_datetime_now.dart`; the diagnostic ID differs from the file name.
- Construction sites only; values from other APIs are not tracked.
- Scope exceptions are file-level ownership decisions, not proof of correct calendar modeling.

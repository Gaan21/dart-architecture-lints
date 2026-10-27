<!-- example-scope: isolated enforce_utc_dates -->

> **Example contract: `enforce_utc_dates` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# enforce_utc_dates

**Default severity**: info. Enabled by default.

## What it detects

In files with a path segment `data`, `datasource(s)`, `repository`/`repositories`, `infrastructure`, `models` or `entities`: `dart:core` `DateTime` constructors other than `DateTime.utc`, and `DateTime.parse` calls, unless the result is immediately converted with `.toUtc()`. Epoch constructors with `isUtc: true` and parses of string literals with an explicit `Z` or offset are allowed.

## Why

Instants stored or exchanged as local time shift with the device zone. UTC is unambiguous; civil dates belong in explicitly scoped files.

## Example

```dart
// BAD
final DateTime createdAt = DateTime.parse(json);
```

```dart
// GOOD
final DateTime createdAt = DateTime.parse(json).toUtc();
```

## Disable if

Your data layer stores civil (calendar) values in these folders without separate scoping, or another time abstraction handles zones.

## Options

Fixed since 0.1.0 (the analyzer plugin API has no rule options): include glob `**` (the data-layer segment filter still applies), no exclude globs, and no civil-date or clock exception globs.

## Limits

- Construction sites only; it does not prove that arbitrary variables hold UTC values.
- A parse argument that is not a string literal is reported unless converted.

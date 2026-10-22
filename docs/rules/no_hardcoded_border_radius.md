<!-- example-scope: isolated no_hardcoded_border_radius -->

> **Example contract: `no_hardcoded_border_radius` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_hardcoded_border_radius

**Default severity**: info. Enabled by default.

## What it detects

`BorderRadius.circular` calls with a single integer literal `6`, `12` or `16` in files matching the include globs and not the exclude globs. The message names `AppSpacing.radiusSm`, `radiusMd` or `radiusLg` respectively.

## Why

Token radii keep corner shapes consistent and changeable in one place.

## Example

```dart
// BAD
BorderRadius.circular(12)
```

```dart
// GOOD
BorderRadius.circular(AppSpacing.radiusMd)
```

## Disable if

Your project has no `AppSpacing` radius tokens or uses other token values.

## Options

Sibling keys `include_globs` (default `["**/presentation/**"]`) and `exclude_globs` (default `**/theme/**`, `**/*_painter.dart`, `**/test/**`, `**/tests/**`, `**/*_test.dart`). Providing a list replaces its default.

## Limits

- Only the three integer values; doubles (`12.0`), other values, `Radius.circular` and `BorderRadius.all` are not reported.
- The token names in the message are fixed.

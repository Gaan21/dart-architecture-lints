<!-- example-scope: isolated avoid_unawaited_ignore_without_reason -->

> **Example contract: `avoid_unawaited_ignore_without_reason` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# avoid_unawaited_ignore_without_reason

**Default severity**: info. Enabled by default.

## What it detects

`// ignore:` comments listing `avoid_unawaited`, `avoid_async_in_provider_create` or `avoid_async_wrapper_hides_unawaited`, without a `// ignore-reason: <non-empty reason>` comment on the same or the preceding line.

## Why

Suppressing a governance rule should leave the reason next to the suppression for reviewers.

## Example

```dart
// BAD
// ignore: avoid_unawaited
unawaited(legacy.run());
```

```dart
// GOOD
// ignore-reason: legacy call, migration tracked separately
// ignore: avoid_unawaited
unawaited(legacy.run());
```

## Disable if

You disabled the three unawaited rules, or you track suppressions another way.

## Options

None.

## Limits

- `// ignore_for_file:` comments are not checked.
- Comments after the last token of a file are not scanned.

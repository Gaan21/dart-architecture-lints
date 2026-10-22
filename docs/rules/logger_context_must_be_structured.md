<!-- example-scope: isolated logger_context_must_be_structured -->

> **Example contract: `logger_context_must_be_structured` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# logger_context_must_be_structured

**Default severity**: info. Enabled by default.

**WorkTracker-specific**: fixed `*LoggerService` logging API with a required `context:` argument. Disable outside WorkTracker.

## What it detects

In files under `/lib/`: `warning`, `error` and `critical` calls on receivers named `AppLoggerService`, `appLoggerService` or ending with `LoggerService` (by identifier or static type) that have no `context:` argument, or whose literal context is empty, generic (`test`, `debug`, `tmp`, `temp`, `todo`, `fixme`, `hack`, `xxx`) or not dot-separated identifiers such as `Class.method` or `module.sub.action`.

## Why

A deterministic context lets production logs be grouped and filtered by origin.

## Example

```dart
// BAD
AppLoggerService.error('sync failed', context: 'debug');
```

```dart
// GOOD
AppLoggerService.error('sync failed', context: 'SyncService.push');
```

## Disable if

In any project outside WorkTracker that does not adopt the same convention. Your logging API has no context parameter or structures context differently.

## Options

None. Receiver names and methods are fixed.

## Limits

- Non-literal contexts (variables, interpolation) are not validated.
- Whether the context matches the enclosing member is checked separately by `logger_context_matches_scope`.

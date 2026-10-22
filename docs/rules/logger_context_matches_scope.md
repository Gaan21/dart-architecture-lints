<!-- example-scope: isolated logger_context_matches_scope -->

> **Example contract: `logger_context_matches_scope` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# logger_context_matches_scope

**Default severity**: info. Enabled by default.

## What it detects

Logger calls (`error`/`warning` by default) on configured logger receivers whose `context:` argument is a simple string literal different from `TypeName.member`, where the member name has one leading `_` and a trailing `Internal` removed. The enclosing type may be a class, mixin, enum or named extension.

## Why

A context that matches its real location makes log entries traceable after refactors and copy-paste.

## Example

```dart
// BAD
class SyncService {
  Future<void> push() async {
    logger.error('push failed', context: 'SyncService.pull');
  }
}
```

```dart
// GOOD
class SyncService {
  Future<void> push() async {
    logger.error('push failed', context: 'SyncService.push');
  }
}
```

## Disable if

Your logging API has no context argument or uses another context format.

## Options

Sibling keys: `include_globs` (default `["**/lib/**"]`), `exclude_globs`, `logger_names` (wildcards matching receiver names or resolved type names; without it, receivers named `AppLoggerService`, `appLoggerService` or ending with `LoggerService` match), `methods` (default `[error, warning]`) and `context_argument` (default `context`). Example: `logger_names: ["Logger", "logger"]`. A provided list replaces its default; an empty list matches nothing.

## Limits

- With default receiver names, loggers not named `*LoggerService` are ignored; set `logger_names` for other logging APIs.
- Only literal contexts inside named methods and named constructors are checked; unnamed constructors and top-level functions are skipped.
- It checks scope consistency, not whether logging is appropriate.

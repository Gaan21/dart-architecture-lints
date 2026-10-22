<!-- example-scope: isolated avoid_unawaited -->

> **Example contract: `avoid_unawaited` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# avoid_unawaited

**Default severity**: info. Enabled by default.

**WorkTracker-specific**: fixed WorkTracker `// unawaited-ok: <category> - <reason>` comment format and categories. Disable outside WorkTracker.

## What it detects

Calls to `unawaited` (resolved to `dart:async` when resolvable) without a comment on the same or the preceding line of the form `// unawaited-ok: <category> - <reason>`. Valid categories: `dispose-sync`, `callback-sync`, `telemetry/logging`, `best-effort-cleanup`, `post-frame-init`, `prefetch-noncritical`. A malformed `unawaited-ok` comment produces a distinct message under the same ID.

## Why

Errors in a fire-and-forget future are easy to lose. Requiring a category and reason makes each case reviewable; the called method should handle its own errors.

## Example

```dart
// BAD
unawaited(cache.refresh());
```

```dart
// GOOD
// unawaited-ok: best-effort-cleanup - refresh logs its own failures
unawaited(cache.refresh());
```

## Disable if

In any project outside WorkTracker that does not adopt the same convention. Your team does not govern fire-and-forget futures, or uses only the upstream `unawaited_futures`/`discarded_futures` lints.

## Options

None. Categories are fixed.

## Limits

- Does not verify the no-throw claim or that the category is truthful.
- Other ways of not awaiting a future are covered only by `avoid_async_wrapper_hides_unawaited` and upstream lints.

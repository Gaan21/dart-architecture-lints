<!-- example-scope: isolated avoid_async_in_provider_create -->

> **Example contract: `avoid_async_in_provider_create` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# avoid_async_in_provider_create

**Default severity**: info. Enabled by default.

## What it detects

`unawaited(...)` calls (resolved to `dart:async` when resolvable) inside the `create` or `update` named argument of a constructor whose type name contains `Provider`, unless an enclosing `addPostFrameCallback` call is closer.

## Why

Async work started during build can mutate state while the widget tree is being built, causing build-phase errors and races.

## Example

```dart
// BAD
ChangeNotifierProvider(
  create: (_) {
    final vm = HomeViewModel();
    unawaited(vm.init());
    return vm;
  },
)
```

```dart
// GOOD
ChangeNotifierProvider(
  create: (_) {
    final vm = HomeViewModel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // unawaited-ok: post-frame-init - initialize after build
      unawaited(vm.init());
    });
    return vm;
  },
)
```

## Disable if

The project does not use `provider`-style `create` closures.

## Options

None.

## Limits

- Only explicit `unawaited(...)`; bare unawaited futures and `then` chains are not detected.
- Providers whose type name lacks `Provider`, and helper functions called from `create`, are not checked.

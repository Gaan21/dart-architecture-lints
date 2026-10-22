<!-- example-scope: isolated viewmodels_call_super_dispose -->

> **Example contract: `viewmodels_call_super_dispose` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# viewmodels_call_super_dispose

**Default severity**: info. Enabled by default.

## What it detects

Non-abstract `dispose` methods in classes that extend `ViewModel`, `BaseViewModel`, `ChangeNotifier`, `ValueNotifier`, `Cubit`, `Bloc`, or a superclass whose name contains `ViewModel`, `Model`, `Controller` or `Provider` (also one level up through the resolved supertype), when no `super.dispose()` statement appears in the block body. UI-state classes are left to `uistate_must_call_super_dispose`.

## Why

Skipping `super.dispose()` leaves listeners attached and base-class resources unreleased.

## Example

```dart
// BAD
class CartViewModel extends ChangeNotifier {
  @override
  void dispose() {
    _subscription.cancel();
  }
}
```

```dart
// GOOD
class CartViewModel extends ChangeNotifier {
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

## Disable if

Your view models do not extend a disposable base.

## Options

None.

## Limits

- A call in one branch counts; it does not prove the call runs on every path.
- The name heuristics can include unrelated `*Controller`/`*Model` subclasses; `Cubit`/`Bloc` normally use `close()`, not `dispose()`.

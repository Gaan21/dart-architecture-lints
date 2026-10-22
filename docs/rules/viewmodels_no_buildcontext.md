<!-- example-scope: isolated viewmodels_no_buildcontext -->

> **Example contract: `viewmodels_no_buildcontext` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# viewmodels_no_buildcontext

**Default severity**: info. Enabled by default.

## What it detects

In classes whose name contains `ViewModel`, or that directly extend/implement `ChangeNotifier`, `ValueNotifier`, `Cubit`, `Bloc`, `BaseViewModel` or `ViewModel`: fields and constructor parameters annotated as `BuildContext`.

## Why

A stored context outlives its widget and couples the view model to the widget tree; navigation and dialogs belong to the view through effects.

## Example

```dart
// BAD
class CartViewModel extends ChangeNotifier {
  CartViewModel(this.context);
  final BuildContext context;
}
```

```dart
// GOOD
class CartViewModel extends ChangeNotifier {
  void checkout() => emitEffect(const OpenCheckoutEffect());
}
```

## Disable if

Your state-management approach intentionally passes context into these classes.

## Options

None.

## Limits

- Method parameters (for example `void open(BuildContext context)`) and unannotated fields are not reported.
- Any `ChangeNotifier` subclass is treated as a view model, including UI-state owners.

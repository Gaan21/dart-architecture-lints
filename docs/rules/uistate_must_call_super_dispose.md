<!-- example-scope: isolated uistate_must_call_super_dispose -->

> **Example contract: `uistate_must_call_super_dispose` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# uistate_must_call_super_dispose

**Default severity**: info. Enabled by default.

## What it detects

Non-abstract `dispose` methods in classes whose name ends with `UiState`, or that extend, mix in or implement a type whose name ends with `UiState`, when no `super.dispose()` statement appears in the block body (also inside nested blocks, `if`/`else` branches and `try`/`catch`/`finally`).

## Why

Skipping `super.dispose()` leaves `ChangeNotifier` listeners attached after the owner is gone.

## Example

```dart
// BAD
class SearchUiState extends ChangeNotifier {
  @override
  void dispose() {
    controller.dispose();
  }
}
```

```dart
// GOOD
class SearchUiState extends ChangeNotifier {
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

## Disable if

Your UI-state classes are not `ChangeNotifier`s or have no `dispose` contract.

## Options

None.

## Limits

- A call in only one branch counts as present; it does not prove the call runs on every path.
- Expression-bodied `dispose` methods are reported; view models are covered by `viewmodels_call_super_dispose`.

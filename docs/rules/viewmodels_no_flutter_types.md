<!-- example-scope: isolated viewmodels_no_flutter_types -->

> **Example contract: `viewmodels_no_flutter_types` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# viewmodels_no_flutter_types

**Default severity**: info. Enabled by default.

## What it detects

Fields with an explicit type annotation named `TextEditingController`, `ScrollController`, `AnimationController`, `TabController`, `PageController`, `FocusNode`, `GlobalKey`, `Color`, `TextStyle`, `EdgeInsets`, `BorderRadius`, `BoxDecoration`, `Widget`, `StatelessWidget` or `StatefulWidget`, in any class whose name contains `ViewModel`. `GlobalKey<NavigatorState>` is allowed.

## Why

View models without Flutter types stay testable without widget infrastructure; UI resources belong to a UI-state owner.

## Example

```dart
// BAD
class LoginViewModel {
  final TextEditingController email = TextEditingController();
}
```

```dart
// GOOD
class LoginViewModel {
  String email = '';
}
// LoginUiState owns the TextEditingController.
```

## Disable if

Your architecture lets view models own controllers or styling types.

## Options

None.

## Limits

- Uses the annotation spelling only: fields without a type annotation, generic wrappers (`List<FocusNode>`), getters and parameters are not checked.
- `BuildContext` is covered by `viewmodels_no_buildcontext`.

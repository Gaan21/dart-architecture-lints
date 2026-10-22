<!-- example-scope: isolated viewmodels_extend_base_viewmodel -->

> **Example contract: `viewmodels_extend_base_viewmodel` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# viewmodels_extend_base_viewmodel

**Default severity**: info. Enabled by default.

## What it detects

Concrete public classes whose name ends with `ViewModel`, in files whose URI path contains `/presentation/viewModels/`, whose direct superclass is not `BaseViewModel` or `BaseViewModelWithEffects`.

## Why

The project base class supplies typed UI state, `Result` handling and a disposed-state guard consistently.

## Example

```dart
// BAD
class ProfileViewModel extends ChangeNotifier {}
```

```dart
// GOOD
class ProfileViewModel extends BaseViewModel<Profile> {}
```

## Disable if

Your project has no base view model, or uses another state-management base.

## Options

None.

## Limits

- Direct superclass name only: indirect bases are reported.
- Folders spelled other than `/presentation/viewModels/` are not checked.

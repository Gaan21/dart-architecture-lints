<!-- example-scope: isolated variable_name_should_contain_class_name -->

> **Example contract: `variable_name_should_contain_class_name` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# variable_name_should_contain_class_name

**Default severity**: info. Enabled by default.

## What it detects

Any variable declaration (local, field, top-level, loop) whose resolved class type is not primitive (`int`, `double`, `bool`, `String`, `num`, `void`, `Object`, `dynamic`, `Widget`) and whose name, ignoring case and underscores, does not contain the class name. `List`, `Set`, `Map`, `Iterable`, `Future`, `Stream`, `ValueNotifier`, `ChangeNotifier` and `Notifier` are unwrapped to their first non-primitive type argument.

## Why

Names that contain the type make data flow readable without hovering, especially with many collaborators.

## Example

```dart
// BAD
final DashboardViewModel vm = DashboardViewModel();
```

```dart
// GOOD
final DashboardViewModel dashboardViewModel = DashboardViewModel();
```

## Disable if

Your naming convention prefers short role names (`vm`, `repo`) or names that describe purpose rather than type.

## Options

None.

## Limits

- Parameters are not checked.
- Variables inside a closure that is not within a method are skipped when a comment precedes the declaration.
- Implemented in `lib/variable_name_should_match_class_name.dart`; the diagnostic ID differs from the file name.

<!-- example-scope: isolated no_static_map_controllers -->

> **Example contract: `no_static_map_controllers` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_static_map_controllers

**Default severity**: info. Enabled by default.

## What it detects

A `static` field whose resolved type is a `Map` with a value type that is (or extends) a lifecycle resource such as `TextEditingController`, `FocusNode`, `Timer`, `StreamController` or `StreamSubscription`. Inferred types are resolved.

## Why

Static maps outlive widgets and screens, so stored controllers are never disposed and keep stale state.

## Example

```dart
// BAD
class SearchCache {
  static final Map<String, TextEditingController> controllers = {};
}
```

```dart
// GOOD
class SearchUiState extends ChangeNotifier {
  final TextEditingController textEditingController = TextEditingController();

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }
}
```

## Disable if

You keep a reviewed static registry that disposes every entry explicitly, and accept the leak risk.

## Options

None.

## Limits

- Only `Map` values are inspected; static lists, sets or single resource fields are not reported.
- Resource names are matched by class name, including supertypes.

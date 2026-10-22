<!-- example-scope: isolated mixin_no_state_ownership -->

> **Example contract: `mixin_no_state_ownership` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# mixin_no_state_ownership

**Default severity**: info. Enabled by default.

## What it detects

A field declared in a `mixin` whose resolved type is, or is a subtype of, a lifecycle resource: `TextEditingController`, `ScrollController`, `AnimationController`, `TabController`, `PageController`, `FocusNode`, `Timer`, `StreamController`, `StreamSubscription`, `VideoPlayerController` or `CameraController`. Inferred field types are resolved.

## Why

A mixin has no constructor or reliable disposal hook of its own, so resources it owns are easily leaked. Keep ownership in the class that disposes them.

## Example

```dart
// BAD
mixin Debounce {
  Timer? timer;
}
```

```dart
// GOOD
mixin Debounce {
  void debounce(Timer? timer) => timer?.cancel();
}
```

## Disable if

Your mixins own resources and a reviewed `dispose` override in every host class releases them.

## Options

None.

## Limits

- Matches resource types by class name (including supertypes), not by library.
- Only fields of `mixin` declarations; classes used as mixins and getters returning resources are not checked.

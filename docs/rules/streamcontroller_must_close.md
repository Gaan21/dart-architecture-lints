<!-- example-scope: isolated streamcontroller_must_close -->

> **Example contract: `streamcontroller_must_close` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# streamcontroller_must_close

**Default severity**: info. Enabled by default.

## What it detects

In classes under `/presentation/viewModels/` or with a resolved supertype named `ChangeNotifier`, `BaseViewModel` or `BaseViewModelWithEffects`: each instance field whose resolved type is a `dart:async` `StreamController` (or subtype) and that the class creates (field or constructor initializer that is not a plain reference) must be closed on every normal exit of `dispose`. Cleanup is followed through blocks, branches, returns, conservative loops, `try`/`catch`/`finally` and resolved same-instance helper methods (async helpers must be awaited).

## Why

An unclosed controller keeps listeners and pending events alive after the owner is disposed.

## Example

```dart
// BAD
class FeedViewModel extends ChangeNotifier {
  final StreamController<int> _events = StreamController<int>();
  @override
  void dispose() {
    if (_ready) _events.close();
    super.dispose();
  }
}
```

```dart
// GOOD
class FeedViewModel extends ChangeNotifier {
  final StreamController<int> _events = StreamController<int>();
  @override
  void dispose() {
    _events.close();
    super.dispose();
  }
}
```

## Disable if

Never for owned controllers. Injected (borrowed) controllers are already skipped; do not close them to silence the rule.

## Options

None.

## Limits

- Fields without an initializer, or initialized from an identifier/property (also through parentheses, `as` or `!`), are treated as borrowed and skipped.
- Inherited cleanup helpers, alias transfer, `late` assignments, cascades and `switch` statements are not proved; unsupported paths may report conservatively.
- It does not prove asynchronous close completion or ordering before `super.dispose()`; not a whole-program leak analysis.

# Checked architecture example

The canonical source is:

<!-- checked-example: examples/architecture/lib/presentation/viewModels/event_owner.dart -->
- [EventOwner](lib/presentation/viewModels/event_owner.dart): an owned controller,
  a borrowed stream API, explicit public types and getter-first method order.
  Its `main` subscribes, publishes, awaits a value and closes the owner.
  The test reads this original source file, not copied sample code.

Run from the repository root:

```sh
dart run examples/architecture/lib/presentation/viewModels/event_owner.dart
dart test test/example_fixture_test.dart
```

The source is resolved without analyzer diagnostics and checked with every
registered rule, using default options, by `example_fixture_test.dart`. The entry
is also executed. The [checked-source registry](../../tool/checked_examples.json)
is consumed by that test and the documentation coverage checker; an all-rules
claim outside the registry is rejected. This demonstrates a small real ownership
and style composition, not positive/negative behavior coverage of every rule or
a complete Flutter application. Sketches in individual rule documents have
separate, explicitly isolated contracts.

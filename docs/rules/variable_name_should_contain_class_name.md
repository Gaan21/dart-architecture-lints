<!-- example-scope: isolated variable_name_should_contain_class_name -->

# variable_name_should_contain_class_name

The architecture selection keeps class-containing variable names strict. The
rule uses resolved types and a case-insensitive comparison after removing
underscores. Supported wrappers are inspected for a relevant nested class;
primitive types are exempt. Its existing documented-callback exception remains.

The actual [EventOwner source](../../examples/architecture/lib/presentation/viewModels/event_owner.dart)
uses `_streamController`, not a generic controller abbreviation. The
[runnable guide](../../examples/architecture/README.md) links the original sources
checked under all 48 selected rules. No inline snippet here claims independent
compilation or whole-profile acceptance; see the [coverage matrix](../example_coverage.md).

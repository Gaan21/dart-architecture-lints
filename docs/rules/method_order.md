<!-- example-scope: isolated method_order -->

# method_order

The selected architecture keeps this rule strict: getters and setters first,
then annotated overrides, public methods, and private methods. Constructors and
fields do not participate in the method sequence. Visibility does not move a
getter behind other methods.

Use the actual [EventOwner source](../../examples/architecture/lib/presentation/viewModels/event_owner.dart)
and [runnable guide](../../examples/architecture/README.md) for the checked
48-rule composition. This document has no separate inline code fixture. The
[coverage matrix](../example_coverage.md) distinguishes isolated rule sketches
from executed full-profile sources.

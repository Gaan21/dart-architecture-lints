<!-- example-scope: isolated multiprovider_order -->

> **Example contract: `multiprovider_order` only.** Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md) for executed whole-profile acceptance.

# multiprovider_order

Enforces the optional architecture convention `*UiState` providers before
`*ViewModel` providers. It remains enabled by default and in the architecture
sample. The style-only sample explicitly deselects it.

Classification uses the provider's first written type argument or recognizable
construction/identifier in its `create` expression. It checks direct entries in
a `MultiProvider.providers` list. Spread lists are skipped. Providers with other
names are not ordered.

This is a naming contract, not proof of actual dependency order or absence of
cycles. A passing list still needs dependency review. A project adopting a
different provider composition contract can explicitly set this rule to false;
the default is not relaxed automatically.

See [selection semantics](../configuration.md).

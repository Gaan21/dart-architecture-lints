<!-- example-scope: isolated multiprovider_order -->

> **Example contract: `multiprovider_order` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# multiprovider_order

**Default severity**: info. Enabled by default.

## What it detects

In a direct `providers:` list literal of `MultiProvider`, a provider whose role is `UiState` after one whose role is `ViewModel`. The role comes from the first type argument (`ChangeNotifierProvider<SearchUiState>`) or the type created/returned in `create`, by the name suffix `UiState` or `ViewModel`.

## Why

View models often read UI-state owners when created; declaring UI state first keeps that dependency available.

## Example

```dart
// BAD
MultiProvider(providers: [
  ChangeNotifierProvider<SearchViewModel>(create: (_) => SearchViewModel()),
  ChangeNotifierProvider<SearchUiState>(create: (_) => SearchUiState()),
])
```

```dart
// GOOD
MultiProvider(providers: [
  ChangeNotifierProvider<SearchUiState>(create: (_) => SearchUiState()),
  ChangeNotifierProvider<SearchViewModel>(create: (_) => SearchViewModel()),
])
```

## Disable if

Your project uses a different composition model or naming, or does not use `provider`.

## Options

None.

## Limits

- It enforces a naming contract, not a dependency graph; review actual dependencies.
- Lists with spread elements are skipped; providers of other types are not ordered. Only the first offending provider is reported.

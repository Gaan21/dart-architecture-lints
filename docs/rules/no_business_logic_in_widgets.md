<!-- example-scope: isolated no_business_logic_in_widgets -->

> **Example contract: `no_business_logic_in_widgets` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_business_logic_in_widgets

**Default severity**: info. Enabled by default.

## What it detects

In files under `/presentation/screens/` or `/presentation/widgets/`, inside `build`, `initState` and `_on*` methods of classes directly extending `StatelessWidget`, `StatefulWidget` or `State`: (1) creating a type whose name ends with `UseCase`, `Repository` or `RepositoryImpl`; (2) `.execute()` on a property whose name ends with `UseCase`/`useCase`; (3) `where`, `map` or `fold` with a closure longer than 60 characters containing two or more `&&`/`||`.

## Why

Widgets should render prepared state; domain decisions and orchestration belong to view models or use cases so they can be tested without widgets.

## Example

```dart
// BAD
final active = vm.orders.where((o) => o.isActive && o.total > 0 || o.isPinned && o.owner == user).toList();
```

```dart
// GOOD
final active = context.select((OrdersViewModel vm) => vm.activeOrders);
```

## Disable if

Your widgets deliberately host presentation logic and you review it manually.

## Options

None.

## Limits

- Heuristic: short complex closures, other collection methods, helpers and other method names are not inspected.
- Simple formatting, visibility and layout logic remain allowed, as intended.

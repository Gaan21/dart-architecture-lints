<!-- example-scope: isolated require_keys_in_lists -->

> **Example contract: `require_keys_in_lists` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# require_keys_in_lists

**Default severity**: info. Enabled by default.

## What it detects

In `ListView.builder` and `GridView.builder`, an `itemBuilder` closure with an expression body (`=>`) that directly creates a widget without a `key:` argument. Widgets are recognized by a list of common widget names or by resolved inheritance from `Widget`, `StatelessWidget` or `StatefulWidget`.

## Why

Items that are inserted, removed or reordered need stable identity keys to keep their state attached to the right item.

## Example

```dart
// BAD
ListView.builder(
  itemCount: users.length,
  itemBuilder: (context, index) => UserTile(user: users[index]),
)
```

```dart
// GOOD
ListView.builder(
  itemCount: users.length,
  itemBuilder: (context, index) => UserTile(
    key: ValueKey(users[index].id),
    user: users[index],
  ),
)
```

## Disable if

Your lists are static and never reorder, or keys are applied inside the item widget.

## Options

None.

## Limits

- Block-bodied builders, helper-built widgets and conditional returns are not analyzed.
- It does not check that a key is stable: an index key or a fresh `UniqueKey` passes but is unsuitable for moving items.
- Keys preserve identity; they do not prevent rebuilds.

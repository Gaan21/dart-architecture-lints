<!-- example-scope: isolated overlay_lifecycle_context_safety -->

> **Example contract: `overlay_lifecycle_context_safety` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# overlay_lifecycle_context_safety

**Default severity**: info. Enabled by default.

## What it detects

In the `builder:` closure of `showDialog`, `showModalBottomSheet`, `showGeneralDialog`, `showCupertinoDialog`, `showCupertinoModalPopup`, `showDatePicker`, `showTimePicker` and of routes such as `MaterialPageRoute`, `CupertinoPageRoute`, `PageRouteBuilder`, `DialogRoute`, `RawDialogRoute`, `ModalBottomSheetRoute`, `CupertinoModalPopupRoute`: (A) a local `TextEditingController`, `FocusNode`, `AnimationController`, `ScrollController`, `PageController` or `TabController` declared by the caller and referenced inside the builder; (B) `Theme.of`, `MediaQuery.*Of`, `AppLocalizations.of`, `Navigator.of` and similar static lookups, or `context.read/watch/select`, using a context not declared inside the builder.

## Why

The overlay outlives the caller's frame: a captured controller may be used after disposal, and a captured context may be deactivated when the lookup runs.

## Example

```dart
// BAD
final TextEditingController nameController = TextEditingController();
showDialog(
  context: context,
  builder: (dialogContext) => TextField(
    controller: nameController,
    style: Theme.of(context).textTheme.bodyLarge,
  ),
);
```

```dart
// GOOD
showDialog(
  context: context,
  builder: (dialogContext) => const RenameDialog(),
);
// RenameDialog is a StatefulWidget that owns and disposes its controller
// and uses its own context for Theme.of.
```

## Disable if

The project does not use Flutter overlays.

## Options

None.

## Limits

- Only literal `builder:` closures; builders passed as variables or methods are not analyzed.
- Controllers stored in fields, and lookup classes outside the fixed list, are not detected; `use_build_context_synchronously` covers the await-gap case.

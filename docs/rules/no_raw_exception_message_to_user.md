<!-- example-scope: isolated no_raw_exception_message_to_user -->

> **Example contract: `no_raw_exception_message_to_user` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_raw_exception_message_to_user

**Default severity**: info. Enabled by default.

## What it detects

In files whose URI path contains `/presentation/`, within arguments of `Text`, `SelectableText`, `SnackBar`, `AlertDialog`, `SimpleDialog`, `Tooltip` or calls named `showError`, `showWarning`, `showMessage`, `showInfo`, `showAlert`, `showDialog`, `showToast`, `showNotification`, `showSnackbar`/`ShowSnackbar`: `.message` or `.toString()` on identifiers that look like errors (`e`, `err`, `error`, `ex`, `exception`, `failure`, or names containing `error`/`exception` or ending with `Failure`), including inside interpolation, and identifiers such as `errorMessage`, `exceptionMessage`, `backendMessage`, `rawMessage`.

## Why

Exception text is not user copy: it is untranslated, unstable and may leak internal details. Show localized text resolved from a stable error code.

## Example

```dart
// BAD
Text(error.message)
```

```dart
// GOOD
Text(context.l10n.errorMessageFor(error.code))
```

## Disable if

Your product deliberately shows server-provided messages that are already localized and safe.

## Options

None.

## Limits

- Name-based: variables with other names, and messages passed through helpers or state fields, are not detected.
- The right side of `??` is left to `no_exception_message_passthrough`.

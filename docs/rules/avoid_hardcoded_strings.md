<!-- example-scope: isolated avoid_hardcoded_strings -->

> **Example contract: `avoid_hardcoded_strings` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# avoid_hardcoded_strings

**Default severity**: info. Enabled by default.

## What it detects

Simple string literals of two or more characters that contain none of `.`, `/`, `#`, `_` or `:`, in files whose lowercased path has a `presentation` or `usecases` segment. Files with any path segment containing `test` are skipped.

## Why

User-facing text should come from the localization system so it can be translated and reviewed.

## Example

```dart
// BAD
Text('Save changes')
```

```dart
// GOOD
Text(AppLocalizations.of(context).saveChanges)
```

## Disable if

The app is not localized, or the heuristic reports too many non-user strings (keys, log text, identifiers) in your code base.

## Options

None.

## Limits

- Heuristic: any literal without the excluded characters is reported, including map keys, log messages and enum-like names.
- Interpolated strings are not reported; strings outside the two path segments are not checked.
- A path segment merely containing `test` (for example `contest`) skips the file.

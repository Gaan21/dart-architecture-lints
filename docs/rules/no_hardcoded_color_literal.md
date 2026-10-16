<!-- example-scope: isolated no_hardcoded_color_literal -->

> **Example contract: `no_hardcoded_color_literal` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# `no_hardcoded_color_literal`

Prevents using `Color(0x...)` with a hardcoded hex integer literal in presentation files.

Hardcoded color values bypass the design-token system and make theme changes brittle.
All colors in the presentation layer should come from `AppColors` constants or
`Theme.of(context).colorScheme.*`.

## What it reports

Reports any `Color(0x...)` constructor call where the argument is an integer hex
literal (`0xFF...` / `0x...`) in files matched by `include_globs` (minus `exclude_globs`).

Message:

> Evita Color(0x...) directo en presentación — usa un token de AppColors o Theme.of(context).colorScheme.*

## Default scope

Included:
- `**/presentation/**`

Excluded (hardcoded defaults):
- `**/theme/**` — token definition files are exempt
- `**/*_painter.dart` — branding/canvas painters are exempt
- `**/test/**`, `**/tests/**`, `**/*_test.dart`

## Configuration

```yaml
custom_lint:
  rules:
    - no_hardcoded_color_literal:
        include_globs:
          - "**/presentation/**"
        exclude_globs:
          - "**/theme/**"
          - "**/*_painter.dart"
          - "**/test/**"
          - "**/*_test.dart"
```

## Examples

```dart
// ❌ BAD
Container(color: Color(0xFF0F766E))
Container(color: const Color(0x1ADC2626))

// ✅ GOOD
Container(color: AppColors.colorPrimary)
Container(color: Theme.of(context).colorScheme.primary)
Container(color: Colors.transparent)           // named constant, not Color(int)
Container(color: Color.fromARGB(255, 15, 118, 110)) // different constructor, not flagged
```

## Expected false positives / false negatives

- No false positives for `Color.fromARGB`, `Color.fromRGBO`, named constants
  (`Colors.transparent`, etc.) or variable arguments (`Color(myVar)`).
- Files inside `theme/` are always excluded — `AppColors`, `ColorPalette`,
  `ThemeExtensions`, etc. are never reported.

## Testing guide (external project)

1. Enable the rule in `analysis_options.yaml`.
2. Add `Color(0xFF123456)` inside a widget in `lib/presentation/screens/` and run:

```bash
dart run custom_lint
```

3. Confirm the warning appears for that widget.
4. Confirm no warning appears for `AppColors.someColor` or inside `lib/presentation/theme/`.

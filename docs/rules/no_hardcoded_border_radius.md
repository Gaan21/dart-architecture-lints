# `no_hardcoded_border_radius`

Prevents using `BorderRadius.circular(n)` with a literal value that has a named
spacing token in `AppSpacing`.

Hardcoded radius values bypass the design-token system. When a token exists for
a value, it must be used so that radius changes propagate uniformly.

## What it reports

Reports `BorderRadius.circular(n)` calls where `n` is one of the following
**exact integer literals** that have a corresponding `AppSpacing` token:

| Literal | Required token |
|---------|----------------|
| `6`     | `AppSpacing.radiusSm` |
| `12`    | `AppSpacing.radiusMd` |
| `16`    | `AppSpacing.radiusLg` |

Messages are value-specific, e.g.:

> Usa AppSpacing.radiusMd en lugar de BorderRadius.circular(12)

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
    - no_hardcoded_border_radius:
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
BorderRadius.circular(6)   // → use AppSpacing.radiusSm
BorderRadius.circular(12)  // → use AppSpacing.radiusMd
BorderRadius.circular(16)  // → use AppSpacing.radiusLg

// ✅ GOOD
BorderRadius.circular(AppSpacing.radiusSm)
BorderRadius.circular(AppSpacing.radiusMd)
BorderRadius.circular(AppSpacing.radiusLg)
BorderRadius.circular(8)   // no token for 8 → not flagged
BorderRadius.circular(20)  // no token for 20 → not flagged
```

## Expected false positives / false negatives

- Values with no token (e.g. `8`, `10`, `20`) are never reported.
- `BorderRadius.only(...)`, `BorderRadius.all(...)` and other constructors are
  out of scope — only `BorderRadius.circular` is checked.

## Testing guide (external project)

1. Enable the rule in `analysis_options.yaml`.
2. Add `BorderRadius.circular(12)` inside a widget in `lib/presentation/screens/` and run:

```bash
dart run custom_lint
```

3. Confirm the warning appears with the message pointing to `AppSpacing.radiusMd`.
4. Confirm `BorderRadius.circular(8)` produces no warning.

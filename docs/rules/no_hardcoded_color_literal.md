<!-- example-scope: isolated no_hardcoded_color_literal -->

> **Example contract: `no_hardcoded_color_literal` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_hardcoded_color_literal

**Default severity**: info. Enabled by default.

## What it detects

Unnamed `Color(...)` constructor calls with a single hexadecimal integer literal argument (`0x`/`0X`), in files matching the include globs and not the exclude globs.

## Why

Raw colors bypass the design tokens and theme, so light/dark and brand changes miss them.

## Example

```dart
// BAD
Container(color: Color(0xFF1E88E5))
```

```dart
// GOOD
Container(color: Theme.of(context).colorScheme.primary)
```

## Disable if

The project does not use color tokens, or the reported folders legitimately define colors.

## Options

Fixed since 0.1.0 (the analyzer plugin API has no rule options): include glob `**/presentation/**`; exclude globs `**/*_painter.dart`, `**/theme/**`, `**/test/**`, `**/tests/**`, `**/*_test.dart`.

## Limits

- `Color.fromARGB`, `Color.fromRGBO`, decimal literals, constants and `Colors.*` are not reported.
- Does not check that a token is semantically right for the context.

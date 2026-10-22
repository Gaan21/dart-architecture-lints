<!-- example-scope: isolated no_bang_operator -->

> **Example contract: `no_bang_operator` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_bang_operator

**Default severity**: info. Enabled by default.

## What it detects

Every postfix null-assertion operator (`value!`) in non-generated files.

## Why

A failed assertion throws at runtime. Null-aware operators, explicit checks or promotion make the null case visible.

## Example

```dart
// BAD
String label(String? name) => name!;
```

```dart
// GOOD
String label(String? name) => name ?? 'unknown';
```

## Disable if

Your team uses `!` where an invariant is established and reviewed, and prefers the analyzer's own nullability checks over a blanket ban.

## Options

None.

## Limits

- Reports every `!` postfix, including ones guarded by an earlier check the analyzer cannot promote (for example fields).
- Does not judge whether a replacement default is semantically correct; do not add synthetic defaults only to silence it.

<!-- example-scope: isolated no_bang_operator -->

> **Example contract: `no_bang_operator` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# `no_bang_operator`

Prevents use of the null assertion operator `!` anywhere in the codebase.

The `!` operator throws a `Null check on null value` runtime exception when the
value is `null`. It is almost always replaceable with a safer null-aware pattern
that makes the intent explicit and eliminates crash risk.

## What it reports

Reports every postfix `!` expression.

Message:

> El operador ! puede causar crashes en runtime si el valor es null. Debe reemplazarse con patrones más seguros de manejo de nulos.

## Examples

```dart
// ❌ BAD
final name = user!.name;
return value!;

// ✅ GOOD
final name = user?.name ?? 'unknown';
final name = user != null ? user.name : 'unknown';
if (value != null) return value;
return value ?? defaultValue;
```

## Notes

- Applies to the entire project (no path filtering).
- Generated files are automatically skipped.
- There is no allowlist — if `!` is genuinely required (e.g. interop), suppress
  with `// ignore: no_bang_operator` and document the reason.

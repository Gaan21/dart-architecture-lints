<!-- example-scope: isolated enforce_final_variables -->

> **Example contract: `enforce_final_variables` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# enforce_final_variables

**Default severity**: info. Enabled by default.

## What it detects

A local `var` declaration whose variables are never written again in the enclosing function body. Writes include assignments, compound assignments, increments and writes inside closures, found through resolved elements.

## Why

A `final` local tells the reader the binding does not change.

## Example

```dart
// BAD
void run() {
  var total = 0;
  print(total);
}
```

```dart
// GOOD
void run() {
  final total = 0;
  var count = 0;
  count++;
  print([total, count]);
}
```

## Disable if

Your style guide prefers `var` for locals, or you rely on the upstream `prefer_final_locals` lint instead.

## Options

None.

## Limits

- Only `var`; explicitly typed non-final locals (`int x = 0;`) are not reported.
- Loop variables of `for` and `for-in` are allowed.
- Fields and top-level variables are never reported, because other libraries may write them.

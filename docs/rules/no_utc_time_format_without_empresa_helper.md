<!-- example-scope: isolated no_utc_time_format_without_empresa_helper -->

> **Example contract: `no_utc_time_format_without_empresa_helper` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_utc_time_format_without_empresa_helper

**Default severity**: info. Enabled by default.

## What it detects

In files matching the include globs: `.format(x)` calls on a `DateFormat` time pattern (pattern with `H`, `h`, `k`, `K`, `j` or `J` outside quotes, `DateFormat.Hm/Hms/j/jm/jms/jmv/jmz/jmsvz`, variables initialized with one, or receivers whose name contains `time`, `hour`, `hora`, `hm`, `hms`, `heure`, `minute` or `clock`) where `x` is not an invocation matching `allowed_wrappers`, and is not a local variable whose last declaration/assignment in an enclosing block of the same function used an approved wrapper.

## Why

Formatting a UTC instant directly renders the server zone, not the organization's local time.

## Example

```dart
// BAD
Text(DateFormat('HH:mm').format(movement.timestampUtc))
```

```dart
// GOOD
Text(DateFormat('HH:mm').format(movement.timestampUtc.toEmpresaLocalTime(tz)))
```

## Disable if

Your product shows times in UTC or device-local time intentionally.

## Options

Sibling keys: `include_globs` (default `**/presentation/**`, `**/screens/**`, `**/widgets/**`, `**/ui/**`), `exclude_globs` (default `**/test/**`, `**/tests/**`, `**/*_test.dart`), `allowed_wrappers` (default `*.toEmpresaLocalTime`, `EmpresaDateTimeFormatter.*`) and `allow_utc_debug_context` (default `false`; `true` skips calls inside an interpolation whose text contains `UTC`).

## Limits

- A formatter passed as a variable into another function is not detected unless its name exposes time.
- Conversion is tracked by statement order per block, not by full data flow; `empresa` is the domain word for the organization owning the record.

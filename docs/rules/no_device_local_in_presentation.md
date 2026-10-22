<!-- example-scope: isolated no_device_local_in_presentation -->

> **Example contract: `no_device_local_in_presentation` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_device_local_in_presentation

**Default severity**: info. Enabled by default.

## What it detects

Calls to a method named `toLocal` with no arguments, in files matching the include globs and not the exclude globs, unless the receiver matches `allowed_receivers` or the call is inside an invocation matching `allowed_wrappers`.

## Why

Device-local time is wrong whenever the user is outside the organization's time zone; presentation should render values through an approved zone-aware helper.

## Example

```dart
// BAD
Text(DateFormat.Hm().format(entry.startUtc.toLocal()))
```

```dart
// GOOD
Text(DateFormat.Hm().format(entry.startUtc.toEmpresaLocalTime(tz)))
```

## Disable if

Your app intentionally displays times in the device zone.

## Options

Sibling keys: `include_globs` (default `**/presentation/**`, `**/ui/**`, `**/screens/**`, `**/widgets/**`), `exclude_globs`, `allowed_receivers` (wildcards matched against the receiver source) and `allowed_wrappers` (wildcards matched against `method`, `Target.method`; `allowed_helpers` is a fallback alias).

## Limits

- Matches the method name, not the resolved `DateTime` type.
- Conversions done outside the included paths and then displayed are not detected.

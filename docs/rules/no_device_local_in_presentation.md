<!-- example-scope: isolated no_device_local_in_presentation -->

> **Example contract: `no_device_local_in_presentation` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_device_local_in_presentation

**Default severity**: info. Enabled by default.

**WorkTracker-specific**: WorkTracker displays organization-zone time; ordinary apps legitimately show device-local time. Disable outside WorkTracker.

## What it detects

Calls to a method named `toLocal` with no arguments, in files matching the include globs.

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

In any project outside WorkTracker that does not adopt the same convention. Your app intentionally displays times in the device zone.

## Options

Fixed since 0.1.0 (the analyzer plugin API has no rule options): include globs `**/presentation/**`, `**/ui/**`, `**/screens/**`, `**/widgets/**`; no exclude globs, allowed receivers or allowed wrappers.

## Limits

- Matches the method name, not the resolved `DateTime` type.
- Conversions done outside the included paths and then displayed are not detected.

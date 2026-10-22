<!-- example-scope: isolated no_civil_utc_mix_without_helper -->

> **Example contract: `no_civil_utc_mix_without_helper` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_civil_utc_mix_without_helper

**Default severity**: info. Enabled by default.

## What it detects

In files matching the include globs (default mappers/formatters/adapters folders): binary expressions with `+`, `==`, `!=`, `<`, `<=`, `>`, `>=`, string interpolations with two or more parts, and calls to `compareTo`, `difference`, `isBefore`, `isAfter`, `isAtSameMomentAs`, `format`, `merge` or `combine`, where one side shows civil-date evidence and the other instant evidence. Evidence comes from names (`date`, `day`, `fecha`, `civil`... versus `timestamp`, `utc`, `time`, `epoch`, `hour`...), instant members (`toUtc`, `millisecondsSinceEpoch`, `hour`...), `DateTime` constructors and parsed literals. Calls inside an invocation matching `helper_whitelist` are skipped.

## Why

A calendar date and a UTC instant mean different things; mixing them silently shifts dates across time zones.

## Example

```dart
// BAD
final bool sameDay = workday.date == entry.timestampUtc;
```

```dart
// GOOD
final bool sameDay = workday.date == TimeContract.normalizeCivilDate(entry.timestampUtc);
```

## Disable if

Your mapping code has no civil-date concept, or naming in your code base produces too many false positives.

## Options

Sibling keys: `include_globs` (default `**/mappers/**`, `**/formatters/**`, `**/adapters/**`), `exclude_globs` (default `**/test/**`, `**/tests/**`, `**/*_test.dart`), `helper_whitelist` (wildcards matching `method`, `Target.method`) and `strict_mode` (default `false`; `true` reports any operator, single-part interpolation and any call).

## Limits

- Naming-based evidence: mixes without civil/instant names or risky operations are not detected; matching names in unrelated code can report.
- Calls on a target whose arguments are plain identifiers and whose result is returned or used as a statement are treated as pass-through and skipped.

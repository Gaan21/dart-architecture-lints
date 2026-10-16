<!-- example-scope: isolated no_civil_utc_mix_without_helper -->

> **Example contract: `no_civil_utc_mix_without_helper` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# `no_civil_utc_mix_without_helper`

Detects risky mixing of civil/date-only values with UTC instant values inside
mappers/formatters/adapters when no approved helper is used.

This rule uses a dual-evidence strategy to reduce false positives:

- Civil evidence and instant evidence must appear in the same expression/scope.
- By default, it warns only on high-risk combinations (comparison,
  interpolation, merge/combine/compare-like invocations).
- In `strict_mode: true`, it broadens detection for mixed invocations in the
  same scope.

Message:

> Detected civil-date + UTC-instant mix without approved helper.

## Default scope

- `**/mappers/**`
- `**/formatters/**`
- `**/adapters/**`

Default excludes:

- `**/test/**`
- `**/tests/**`
- `**/*_test.dart`

## Configuration

```yaml
custom_lint:
  rules:
    - no_civil_utc_mix_without_helper:
        include_globs:
          - "**/mappers/**"
          - "**/formatters/**"
          - "**/adapters/**"
        exclude_globs:
          - "**/test/**"
          - "**/*_test.dart"
        helper_whitelist:
          - "TimeContract.normalizeCivilDate"
          - "EmpresaDateTimeFormatter.*"
        strict_mode: false
```

## Examples

```dart
// ❌ BAD
String mapLabel(String civilDate, DateTime createdAtUtcDateTime) {
  return 'civil=$civilDate instant=$createdAtUtcDateTime';
}

// ✅ GOOD (passthrough wrapper, no real mix operation)
Future<void> saveTask(String civilDate, DateTime timestampUtcDateTime) {
  return repository.saveTask(civilDate, timestampUtcDateTime);
}

// ✅ GOOD
String mapLabel(String civilDate, DateTime createdAtUtcDateTime) {
  return TimeContract.normalizeCivilDate(civilDate, createdAtUtcDateTime);
}
```

## Expected false positives / false negatives

- False positive (reduced): simple delegation wrappers and test files are
  ignored by default.
- False negative (expected): if naming does not expose civil/UTC intent and no
  clear risky operation exists, enable `strict_mode` or refine naming.

## Migration tips

1. Standardize naming (`civilDate`, `timestampUtc`, `createdAtDateTime`) so
   intent is explicit.
2. Route mixed operations through a dedicated time contract helper.
3. Add project-approved helpers to `helper_whitelist`.
4. Keep default excludes for tests; only override when needed.
5. Enable `strict_mode: true` only after baseline cleanup.

## Testing guide (external project)

1. Enable rule in `analysis_options.yaml`.
2. Add a mapper mixing `civilDate` + `createdAtUtcDateTime` in interpolation or
   comparison.
3. Run:

```bash
dart run custom_lint
```

4. Verify lint appears; then wrap logic in whitelisted helper and verify it is
   no longer reported.

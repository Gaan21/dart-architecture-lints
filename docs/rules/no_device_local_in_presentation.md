# `no_device_local_in_presentation`

Prevents direct usage of `DateTime.toLocal()` in presentation/UI files.

This rule exists to avoid accidental device-timezone conversion in widgets/screens,
which can produce inconsistent UX when backend values are already timezone-aware.

## What it reports

Reports any `.toLocal()` call in files matched by `include_globs` (minus
`exclude_globs`) unless the receiver or wrapper is explicitly allowlisted.

Message:

> Avoid DateTime.toLocal() in presentation layer. Use backend timezone-aware values or approved time helper.

## Default scope

- `**/presentation/**`
- `**/ui/**`
- `**/screens/**`
- `**/widgets/**`

## Configuration

```yaml
custom_lint:
  rules:
    - no_device_local_in_presentation:
        include_globs:
          - "**/presentation/**"
          - "**/ui/**"
        exclude_globs:
          - "**/presentation/legacy/**"
        allowed_receivers:
          - "approvedTime"
          - "backendClock.*"
        allowed_wrappers:
          - "TimeContract.*"
          - "EmpresaDateTimeFormatter.*"
        # alias supported:
        # allowed_helpers:
        #   - "TimeContract.*"
```

## Examples

```dart
// ❌ BAD
String render(DateTime value) => value.toLocal().toIso8601String();

// ✅ GOOD
String render(DateTime value) => TimeContract.toDisplayDate(value);
```

## Expected false positives / false negatives

- False positive (expected): a project-specific safe wrapper may still be
  flagged until you add it to `allowed_wrappers`.
- False negative (expected): wrapper methods that internally call `.toLocal()`
  are allowed once whitelisted, even if implementation quality is poor.

## Migration tips

1. Introduce a dedicated time helper (for example `TimeContract` or
   `CompanyDateTimeFormatter`) in application/core.
2. Replace direct `.toLocal()` in UI with that helper.
3. Add only approved wrappers to `allowed_wrappers`.
4. Keep `allowed_receivers` short and explicit.

## Testing guide (external project)

1. Enable the rule in your target project `analysis_options.yaml`.
2. Add one `.toLocal()` usage in `presentation` and run:

```bash
dart run custom_lint
```

3. Confirm lint appears in UI file and does not appear in non-included layers.

# Timezone Safety Rules

Portable setup guide for enabling timezone-safety checks in any Flutter/Dart
project using this lint package.

## Rules included

- `no_device_local_in_presentation`
- `no_civil_utc_mix_without_helper`
- `no_utc_time_format_without_empresa_helper`

## Minimal copy-paste config

```yaml
custom_lint:
  rules:
    - no_device_local_in_presentation
    - no_civil_utc_mix_without_helper
    - no_utc_time_format_without_empresa_helper
```

## Recommended config for multi-project portability

```yaml
custom_lint:
  rules:
    - no_utc_time_format_without_empresa_helper:
        include_globs:
          - "**/presentation/**"
          - "**/screens/**"
          - "**/widgets/**"
          - "**/ui/**"
        exclude_globs:
          - "**/test/**"
          - "**/*_test.dart"
        allowed_wrappers:
          - "*.toEmpresaLocalTime"
          - "EmpresaDateTimeFormatter.*"

    - no_device_local_in_presentation:
        include_globs:
          - "**/presentation/**"
          - "**/ui/**"
          - "**/screens/**"
          - "**/widgets/**"
        exclude_globs:
          - "**/legacy/**"
        allowed_wrappers:
          - "TimeContract.*"
          - "CompanyDateTimeFormatter.*"
        # alias also supported:
        # allowed_helpers:
        #   - "TimeContract.*"

    - no_civil_utc_mix_without_helper:
        include_globs:
          - "**/mappers/**"
          - "**/formatters/**"
          - "**/adapters/**"
        exclude_globs:
          - "**/test/**"
          - "**/tests/**"
          - "**/*_test.dart"
        helper_whitelist:
          - "TimeContract.normalizeCivilDate"
          - "CompanyDateTimeFormatter.*"
        strict_mode: false
```

## Tuning sensitivity

1. Start with defaults (`strict_mode: false`) to avoid noisy detections.
2. If you still have missed mixed flows, enable `strict_mode: true` for the
   rule.
3. Keep helper APIs explicit and add them to `helper_whitelist`.
4. Expand `include_globs` incrementally (for example add `**/repositories/**`)
   only if that layer contains real mapping/normalization logic.

## Other folder layouts

For non-Flutter or custom structures, adjust globs only; rule logic remains
portable:

```yaml
custom_lint:
  rules:
    - no_device_local_in_presentation:
        include_globs:
          - "src/ui/**"
          - "src/features/**/view/**"
    - no_civil_utc_mix_without_helper:
        include_globs:
          - "src/mapping/**"
          - "src/format/**"
          - "src/adapters/**"
        exclude_globs:
          - "test/**"
          - "**/*_spec.dart"
```

## Migration tips

1. Introduce one explicit time-contract helper used across mappers/formatters/UI.
2. Replace direct `.toLocal()` usage in UI with helper calls.
3. Normalize civil-date vs instant conversions in the helper layer.
4. Start with `strict_mode: false`, then tighten once naming/flows are clean.

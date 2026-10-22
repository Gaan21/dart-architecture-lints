# Configuration details

All 52 rules are enabled by default. A project disables individual rules and sets
options in its own `analysis_options.yaml`. There are no presets or profiles, and
installing or updating this package never changes a project's configuration.

## Syntax (custom_lint 0.8.1)

```yaml
analyzer:
  plugins:
    - custom_lint
  errors:
    no_bang_operator: warning
custom_lint:
  rules:
    - no_late_keyword: false
    - require_explicit_types: true
      policy: selective
      local_names: ["*Boundary", "payload"]
```

- `rules` is a **list**. `- rule_name: false` disables one rule.
- Options are sibling keys after the rule key in the same list entry. A nested
  options map (`- rule: {policy: selective}`) is not read by this version.
- Severity overrides belong in `analyzer.errors`; values such as
  `rule_name: warning` under `custom_lint.rules` are not severities.
- `enable_all_lint_rules: false` disables every rule not listed with `true`;
  omit it to keep the default (all enabled).
- `dart run custom_lint` 0.8.1 treats warnings **and infos** as fatal by default.
  Use `--no-fatal-infos` or `--no-fatal-warnings` only as a deliberate CI policy.

## Rules with options

Each rule document lists its option keys and defaults. Providing a list option
replaces its default; an empty list matches nothing.

| Rule | Options |
|------|---------|
| [`require_explicit_types`](rules/require_explicit_types.md) | `policy` (`strict` default, `selective`), `local_names` |
| [`enforce_utc_dates`](rules/enforce_utc_dates.md) | `include_globs`, `exclude_globs`, `civil_date_globs`, `clock_globs` |
| [`no_local_datetime_constructors`](rules/no_local_datetime_constructors.md) | `include_globs`, `exclude_globs`, `civil_date_globs`, `clock_globs` |
| [`logger_context_matches_scope`](rules/logger_context_matches_scope.md) | `include_globs`, `exclude_globs`, `logger_names`, `methods`, `context_argument` |
| [`no_domain_entities_in_presentation_ui`](rules/no_domain_entities_in_presentation_ui.md) | `project_package_name`, `include_globs`, `allowed_file_globs` |
| [`no_device_local_in_presentation`](rules/no_device_local_in_presentation.md) | `include_globs`, `exclude_globs`, `allowed_receivers`, `allowed_wrappers` |
| [`no_civil_utc_mix_without_helper`](rules/no_civil_utc_mix_without_helper.md) | `include_globs`, `exclude_globs`, `helper_whitelist`, `strict_mode` |
| [`no_utc_time_format_without_empresa_helper`](rules/no_utc_time_format_without_empresa_helper.md) | `include_globs`, `exclude_globs`, `allowed_wrappers`, `allow_utc_debug_context` |
| [`no_hardcoded_color_literal`](rules/no_hardcoded_color_literal.md) | `include_globs`, `exclude_globs` |
| [`no_hardcoded_border_radius`](rules/no_hardcoded_border_radius.md) | `include_globs`, `exclude_globs` |

Defaults are generic: `logger_context_matches_scope` checks `**/lib/**`, and
`no_domain_entities_in_presentation_ui` checks imports of the analyzed package's
own `domain/entities`. Override them only for a different layout or logging API:

```yaml
custom_lint:
  rules:
    - logger_context_matches_scope: true
      logger_names: ["Logger", "logger"]
    - no_domain_entities_in_presentation_ui: true
      project_package_name: shared_domain
```

## WorkTracker-specific rules

This package is maintained for WorkTracker. Rules marked ⚠️ in the README encode
WorkTracker's own names or conventions; each document has a
`**WorkTracker-specific**` line saying what is fixed. Outside WorkTracker, paste
the README's generated "Using this outside WorkTracker" block. The classification
lives in `tool/rule_metadata.json` and the generator rejects inconsistent
metadata, documents or README output.

## Result outcome rules

`repository_methods_return_result` and `datasources_return_result` share one
resolved return-type classifier (`lib/result_return_types.dart`). Public
operations return `Result`, or `Future`/`FutureOr`/`Stream` of `Result`
(typedef aliases included). Synchronous getters, private helpers, setters,
void-like returns and `Object` overrides may return values directly;
asynchronous getters remain operations. Neither rule infers infallibility or
purity from names or signatures. `no_result_throw` reports `throw`/`rethrow` that
can leave a use-case/repository method, exempting only throws caught by a
matching clause of an enclosing `try` block in the same function body.

## Domain values

`domain_values_shallow_immutable` checks immutability without a generator and
accepts Freezed-annotated classes. `domain_entities_must_use_freezed` is a Freezed
convention: a project that does not use Freezed for domain values disables it.
Neither rule reads `pubspec.yaml`. Both are shallow: annotations and final fields
do not prove deep immutability.

## Generated files and checks

```sh
dart run tool/generate_rule_tables.dart
dart run tool/generate_rule_tables.dart --check
dart test
```

The generator instantiates the actual plugin registrations, requires metadata
(`id`, `section`, `detects`, `disable_if`, `worktracker_specific` and, when true,
`worktracker_reason`) for exactly those rules, requires every
rule to be enabled by default, and validates each rule document's headings and
default severity. `--check` reports drift without writing. Registration and
configuration coverage of all rules does not imply behavior coverage of all
rules; see the [coverage matrix](example_coverage.md).

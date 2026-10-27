# Configuration details

All 52 rules are enabled by default. A project disables individual rules in its
own `analysis_options.yaml`. There are no presets or profiles, and installing or
updating this package never changes a project's configuration.

Since 0.1.0 this package is an analyzer plugin (`analysis_server_plugin`), run
by `dart analyze`, `flutter analyze` and the IDE. It needs Dart 3.13 or later
(the Flutter release that ships it). `custom_lint` is no longer used.

## Syntax

```yaml
plugins:
  dart_architecture_lints:
    git:
      url: https://github.com/Gaan21/dart-architecture-lints
      ref: <commit sha>
    diagnostics:
      no_late_keyword: false
      method_order: warning
```

- `plugins` is a top-level key of the analyzed package's options. The source is
  `git:` (`url`, `ref`) or a local `path:`; the analysis server fetches and
  builds it. The plugin is not a `pubspec.yaml` dependency.
- `diagnostics` is a **map** keyed by rule ID. `false` disables a rule; `true`
  keeps it; `info`, `warning` or `error` changes the severity it reports.
- With analyzer 14.6, `ignore` is accepted by the options validator but does
  **not** disable a rule, and `disable` disables it with an `unsupported_option`
  warning. Use `false`.
- Diagnostics are printed with the bare rule ID (for example
  `- no_bang_operator`). Every rule reports **info** by default; `dart analyze`
  exits non-zero for infos only with `--fatal-infos`, and for `warning`/`error`
  overrides by default.
- Plugins cannot be configured per rule. Rule options do not exist (see below).

## Suppressing a diagnostic

Ignore comments must name the plugin:

```dart
// ignore: dart_architecture_lints/no_bang_operator
final int count = values!.length;
// ignore_for_file: dart_architecture_lints/one_class_per_file
```

A bare `// ignore: no_bang_operator`, valid with custom_lint, no longer
suppresses anything. `avoid_unawaited_ignore_without_reason` checks both forms.

## Fixed rule options

The analyzer plugin API gives rules no options, so every former option keeps
the default that ran when no option was given. Each rule document lists them
under "Options".

| Rule | Fixed behavior (former options) |
|------|---------------------------------|
| [`require_explicit_types`](rules/require_explicit_types.md) | `strict` policy, no `local_names` (`policy`, `local_names`) |
| [`enforce_utc_dates`](rules/enforce_utc_dates.md) | include `**`, no exclude, civil-date or clock globs |
| [`no_local_datetime_constructors`](rules/no_local_datetime_constructors.md) | include `**`, no exclude, civil-date or clock globs |
| [`logger_context_matches_scope`](rules/logger_context_matches_scope.md) | include `**/lib/**`; `*LoggerService` receivers; `error`, `warning`; `context` |
| [`no_domain_entities_in_presentation_ui`](rules/no_domain_entities_in_presentation_ui.md) | analyzed package name; screens/widgets globs; `*_ui_mapper.dart` allowed |
| [`no_device_local_in_presentation`](rules/no_device_local_in_presentation.md) | presentation/ui/screens/widgets globs; no allowed receivers or wrappers |
| [`no_civil_utc_mix_without_helper`](rules/no_civil_utc_mix_without_helper.md) | mappers/formatters/adapters globs, tests excluded; no whitelist; strict mode off |
| [`no_utc_time_format_without_empresa_helper`](rules/no_utc_time_format_without_empresa_helper.md) | presentation/screens/widgets/ui globs, tests excluded; `empresa` wrappers; no UTC debug context |
| [`no_hardcoded_color_literal`](rules/no_hardcoded_color_literal.md) | include `**/presentation/**`; painters, theme and tests excluded |
| [`no_hardcoded_border_radius`](rules/no_hardcoded_border_radius.md) | include `**/presentation/**`; theme, painters and tests excluded |

A project that needs different scopes disables the rule, or suppresses lines.

## Migrating from custom_lint (0.0.x)

1. Remove `custom_lint` and `dart_architecture_lints` from `dev_dependencies`.
2. Replace `analyzer: plugins: [custom_lint]` and the `custom_lint:` section with
   the `plugins:` entry above. Each `- rule: false` becomes `rule: false` under
   `diagnostics:`; `analyzer: errors:` severity overrides for these rules move to
   `diagnostics:` values.
3. Delete rule option keys (`policy`, `include_globs`, `allowed_wrappers`...);
   they are not read. Rules that needed them may report more or less than before.
4. Rewrite `// ignore: <rule>` and `// ignore_for_file: <rule>` comments for these
   rules as `dart_architecture_lints/<rule>`. `// expect_lint:` is not supported.
5. Replace `dart run custom_lint` in CI with `dart analyze` (add
   `--fatal-infos` to keep failing on infos, as custom_lint 0.8.1 did).

Rule IDs, messages and detection are unchanged: a differential run of the old
and new implementations over the test, documentation and example fixtures
reported identical diagnostics.

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

The generator records the actual plugin registrations, requires metadata
(`id`, `section`, `detects`, `disable_if`, `worktracker_specific` and, when true,
`worktracker_reason`) for exactly those rules, requires every
rule to be a warning rule (enabled by default), and validates each rule
document's headings and default severity. `--check` reports drift without
writing. `test/rule_cases.dart` holds a positive and a negative fixture for every
rule; that is not exhaustive behavior coverage. See the
[coverage matrix](example_coverage.md) for documentation examples.

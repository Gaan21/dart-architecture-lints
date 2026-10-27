# Changelog

## 0.1.0 — analyzer plugin (unreleased)

No version tag or release. Review rule and option changes before updating a
consumer; updating never edits a consumer's configuration.

- **Breaking: analyzer plugin instead of custom_lint.** The package is an
  `analysis_server_plugin` 0.3.25 plugin on `analyzer` 14.6.0 (`lib/main.dart`)
  and needs Dart 3.13. `custom_lint` and `custom_lint_builder` are gone.
  Consumers configure it under the top-level `plugins:` key of
  `analysis_options.yaml` and run `dart analyze`; see the migration steps in
  `docs/configuration.md`.
- **Breaking: configuration syntax.** `diagnostics: {rule_id: false}` disables a
  rule; `info`/`warning`/`error` values set its severity. `custom_lint: rules:`
  and `analyzer: errors:` entries for these rules are no longer read.
- **Breaking: ignore comments need the plugin prefix:**
  `// ignore: dart_architecture_lints/<rule_id>`. `avoid_unawaited_ignore_without_reason`
  now also checks prefixed suppressions of the unawaited rules.
- **Breaking: rule options removed.** The plugin API has no per-rule options.
  The 10 rules that read options (`require_explicit_types`, `enforce_utc_dates`,
  `no_local_datetime_constructors`, `logger_context_matches_scope`,
  `no_domain_entities_in_presentation_ui`, `no_device_local_in_presentation`,
  `no_civil_utc_mix_without_helper`, `no_utc_time_format_without_empresa_helper`,
  `no_hardcoded_color_literal`, `no_hardcoded_border_radius`) run with the
  defaults they used when no option was set, documented per rule.
- **Unchanged:** all 52 rule IDs, messages, info severity, enabled-by-default
  contract, generated-file skipping and path scoping. A differential run of the
  custom_lint and plugin implementations over the test, documentation and
  example fixtures (3,576 files) reported identical diagnostics.
- **Tests** run on the analyzer's lint pipeline with the real SDK, and every rule
  has a positive and a negative fixture (`test/rule_cases.dart`).

- **Profiles and legacy pairing removed.** `profiles/` (architecture, legacy,
  style samples), `analysis_options.yaml.template`, the generator's profile
  selection, `--guidance-root`, `--export-contract`, `--verify-contract`,
  `tool/contract_export.dart` and `docs/paired_contract.md` are gone. They served
  only the deprecated guidance runtime. The last commit that contains them is
  `dc959a5`; consumers pinned to it keep working with their own checkout.
- **All rules on by default.** Every registered rule is enabled unless a project
  disables it with `- rule_name: false`. The README has one "Disable a rule"
  example and generated per-category tables (detects, disable if, severity).
  No diagnostic ID was renamed or removed.
- **Uniform rule documents.** Every `docs/rules/<rule>.md` now has the same short
  sections (what it detects, why, example, disable if, options, limits), derived
  from the detector code; the generator checks the format and severity.
  `docs/ALLOWED_EXCEPTIONS.md` and `docs/rules/timezone_safety.md` were removed:
  their accurate exceptions and options moved into the rule documents (the latter
  showed a nested options syntax that custom_lint 0.8.1 does not read).
- **New rule `domain_values_shallow_immutable`** (enabled): non-final instance
  fields, public `late final` fields without initializer and public setters in
  domain entities/value objects; accepts Freezed-annotated classes. Shallow only.
- **Freezed is a convention.** `domain_entities_must_use_freezed` keeps its ID and
  detector and stays enabled; projects that do not use Freezed disable it.
- **Result rules.** `repository_methods_return_result` and
  `datasources_return_result` share a resolved return-type classifier. No longer
  reported: `Stream`/`FutureOr` of `Result` in repositories, `FutureOr` of
  `Result` in data sources, typedef aliases of `Result` returns, `Stream`/`FutureOr`
  of `void`. Newly reported: repository `Stream`/`FutureOr` getters, data-source
  `FutureOr` getters and unannotated overrides inheriting a non-Result type.
- **WorkTracker-specific rules marked.** 17 rules that depend on WorkTracker's own
  names, paths, helpers, tokens or conventions are classified in
  `tool/rule_metadata.json` (`worktracker_specific`, `worktracker_reason`), marked
  ⚠️ in the README tables and in their documents, and listed in a generated
  "Using this outside WorkTracker" YAML block that disables them all at once. They
  stay enabled by default with unchanged detection; the generator enforces the
  marking.
- Diagnostic text no longer cites a private guidance file
  (`no_direct_error_logging_in_data_domain`), and the `app_exception_must_define_code`
  correction example uses a neutral code (`save_failed`).
- **Generic defaults (behavior change: these rules now apply in any project).**
  `logger_context_matches_scope` now defaults to `include_globs: ["**/lib/**"]`
  instead of only paths containing `/work_tracker/lib/`.
  `no_domain_entities_in_presentation_ui` now defaults `project_package_name` to
  the analyzed package (its `package:` URI, else the project pubspec name)
  instead of `work_tracker`. Explicit options still override both.
- Removed the unused `yaml` and `crypto` dev dependencies.
- **`no_result_throw`** no longer reports a `throw`/`rethrow` caught by a matching
  clause of an enclosing `try` block in the same function body. Its document now
  states that `rethrow` is reported (it always was).

## 0.0.6 — first public release

Initial public distribution of the rule set.

- Timezone safety: `no_utc_time_format_without_empresa_helper`,
  `no_civil_utc_mix_without_helper` and `no_device_local_in_presentation`, with
  configurable path globs and approved-wrapper lists, and 44 automated tests.
- Layer boundaries: domain purity, `Result`-returning repositories and data
  sources, view-model constraints, presentation-model boundaries.
- Lifecycle: `super.dispose()` contracts, stream controller closure.
- Logging and error governance, including a rule that keeps credentials and
  tokens out of log metadata and messages.
- Unawaited-future governance.
- The rule catalogue in the README is generated from the plugin's registration
  list rather than maintained by hand.

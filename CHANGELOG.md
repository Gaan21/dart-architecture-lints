# Changelog

## Unreleased

No version tag or release. Review rule and option changes before updating a
consumer; updating never edits a consumer's configuration.

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

# dart-architecture-lints

Static-analysis rules for Dart and Flutter projects that turn recurring architecture and
correctness failures into executable guardrails.

Most of these rules exist because something went wrong once. A defect reached production, or a
convention kept being broken in review. Each time, the fix was cheap and remembering it was not.

**Some defects are better encoded as executable constraints than caught from memory during code
review.** That is what this package is for.

It is not a complete lint framework and it does not replace the standard Dart and Flutter lint
sets. Run it alongside them. Several rules assume a particular Clean Architecture and MVVM
layout and will be noise outside it; the section on reusability below says which.

## The clearest example: a timezone regression

An application displayed times that were wrong by one or two hours, inconsistently, across
screens showing the same record. Different parts of the code derived local time from different
sources. Some formatted a UTC instant directly. Some used the device timezone. Some re-applied a
conversion to a value that had already been converted.

Because a workday belonged to a calendar date, and that date decided which month it was reported
in, this was a correctness defect in the product's primary output rather than a formatting
problem.

The root-cause analysis and the six changes that followed are written up publicly:
**[WorkTracker — Failure case: the UTC display regression](https://github.com/Gaan21/worktracker-case-study/blob/main/docs/failure-case-timezone.md)**.

Three of the rules here came out of it.

### `no_utc_time_format_without_empresa_helper`

Catches time-pattern formatting (`HH:mm`, `jm`, `Hm`, and similar) applied to a value that is
not wrapped by an approved company-time helper. Tracks assignments per scope, so a value
converted in one function and used raw in another is still flagged, and handles named
constructors as well as direct calls.

Does not catch a formatter passed as a variable into another function unless naming exposes the
intent. That gap is documented rather than papered over.

```dart
// flagged: renders the server's UTC instant and labels it as local time
Text(DateFormat('HH:mm').format(movement.timestampUtc));

// accepted: goes through an approved helper
Text(DateFormat('HH:mm').format(movement.timestampUtc.toEmpresaLocalTime(tz)));
```

`empresa` is the domain's word for the organization that owns the record. The name is kept
because it is the anchor for the public write-up above.

### `no_civil_utc_mix_without_helper`

Catches a civil date and a UTC instant combined in the same expression or scope. Uses a
dual-evidence strategy: both kinds of evidence must appear together, and by default it reports
only high-risk combinations, meaning comparison, string interpolation, and merge or
compare-shaped calls.

Does not catch combinations where naming exposes no civil/UTC intent and no risky operation is
present. Enable `strict_mode` if you want those too, at the cost of more false positives.

### `no_device_local_in_presentation`

Catches device-local time (`toLocal()` and equivalents) reaching the presentation layer, which
is correct for a device in one timezone and wrong for every other one.

Does not inspect paths outside the configured include globs.

### Configuration and tests

All three accept `include_globs`, `exclude_globs` and `allowed_wrappers`, so they can be adopted
on new code first instead of failing an entire existing codebase on the first run. That is
usually why a good rule never gets switched on.

```yaml
custom_lint:
  rules:
    - no_utc_time_format_without_empresa_helper: true
      include_globs: ["**/presentation/**", "**/screens/**", "**/widgets/**"]
      exclude_globs: ["**/test/**"]
      allowed_wrappers: ["*.toEmpresaLocalTime", "EmpresaDateTimeFormatter.*"]
```

**44 automated tests** cover these three rules. They cover scope isolation between functions,
variable shadowing in nested blocks, reassignment to a raw value inside an inner scope,
approved-wrapper configuration and glob filtering. Full options in
[`docs/rules/timezone_safety.md`](docs/rules/timezone_safety.md).

## The rule set

See [selectable contracts and exact configuration syntax](docs/configuration.md).
The generated [architecture sample](profiles/architecture.yaml) selects 48 of 51
rules with selective typing. Only the approved blanket language restrictions
`no_late_keyword`, `no_bang_operator` and `one_class_per_file` are deselected;
architecture/resource contracts remain selected. The legacy sample keeps all 51
enabled, and the style sample explicitly selects four style rules. Naming and
method order stay strict in both new recommendations.

### How a project chooses its rules

The project owner selects a sample, reviews its assumptions, and merges the chosen
rules/options into the Flutter package's `analysis_options.yaml`. No sample is
activated by installing the dependency, selecting a guidance profile or pushing
this repository. Without explicit selections the plugin retains all 51 defaults.
With `enable_all_lint_rules: false`, explicitly list each wanted rule; `true` enables
and `false` disables it. Severity goes under `analyzer.errors`.

Document approved deviations in local `AGENTS.md`/native instructions so the agent
does not follow a written obligation that the project deliberately replaced.
Product-specific paths, logger names, time-zone converters and exceptions belong
to that project's configuration and local contracts, not an inferred product ID.
Updating this dependency does not copy or update your configuration. Inspect the
locked source, rule/option changes and new diagnostics before accepting an update.

The companion [guidance project's workflow](https://github.com/Gaan21/flutter-agent-guidelines/blob/develop/docs/project-workflow.md)
explains written guidance versus executable rules and the agent's review-only
response to an update request. The exported pair here describes the stock
architecture sample; arbitrary consumer overrides need separate recorded evidence.

The tables below are generated from the plugin's own registration list, so they cannot drift
from what actually runs.

<!-- AUTOGENERATED:RULE_TOTAL_COUNTS -->
**Total**: **51 registered rules**. All are enabled by default; severity below is the actual LintCode default, before analyzer overrides.
<!-- END AUTOGENERATED:RULE_TOTAL_COUNTS -->

### Timezone Safety Rules

<!-- AUTOGENERATED:Timezone Safety Rules -->
| Rule | Description | Default severity |
|------|-------------|------------------|
| `no_device_local_in_presentation` | Avoid device-local time (`toLocal()`) in the presentation layer; use an approved company-time helper | info |
| `no_civil_utc_mix_without_helper` | Detect civil-date and UTC-instant values mixed in one expression without an approved helper | info |
| `no_utc_time_format_without_empresa_helper` | Detect time formatting on a value not wrapped by an approved company-time helper, which renders UTC instead of company-local time | info |
<!-- END AUTOGENERATED:Timezone Safety Rules -->

### Architecture & Patterns Rules

<!-- AUTOGENERATED:Architecture & Patterns Rules -->
| Rule | Description | Default severity |
|------|-------------|------------------|
| `usecases_follow_pattern` | Enforce UseCase pattern with execute() → Result<T> | info |
| `viewmodels_call_super_dispose` | Ensure ViewModels call super.dispose() | info |
| `no_external_dependencies_in_domain` | Keep domain layer dependency-free | info |
| `no_result_throw` | Prevent throw in UseCases/Repositories, enforce Result<T> | info |
| `viewmodels_no_flutter_types` | Prevent Flutter types in ViewModels (use UiState) | info |
| `domain_entities_must_use_freezed` | Enforce @freezed on domain entities for immutability | info |
| `no_serialization_in_entities` | Prevent fromJson/toJson in domain entities | info |
| `models_must_have_json_serialization` | Ensure data models have JSON serialization | info |
| `usecases_extend_base_usecase` | Enforce UseCases extend BaseUseCase<T, P> for consistent error handling | info |
| `viewmodels_extend_base_viewmodel` | Enforce ViewModels extend BaseViewModel<T> or BaseViewModelWithEffects<T> | info |
| `repository_methods_return_result` | Enforce Repository methods return Future<Result<T>> or Result<T> | info |
| `streamcontroller_must_close` | Ensure StreamController fields are closed in dispose() to prevent memory leaks | info |
| `require_explicit_types` | Require explicit types using strict (legacy) or selective boundary policy | info |
| `datasources_return_result` | Enforce DataSource methods return Future<Result<T>>, Result<T>, or Stream<Result<T>> | info |
| `no_business_logic_in_widgets` | Prevent business logic in Widgets (enforce MVVM separation) | info |
| `avoid_scattered_401_handling` | Keep 401 handling centralised in the auth interceptor instead of scattered across call sites | info |
| `top_level_screens_must_use_base_contract` | Require top-level routed screens to extend a base screen contract for consistent behaviour | info |
| `no_domain_entities_in_presentation_ui` | Forbid presentation UI from depending on domain entities directly; use presentation models | info |
<!-- END AUTOGENERATED:Architecture & Patterns Rules -->

### Logging & Error Governance

<!-- AUTOGENERATED:Logging & Error Governance -->
| Rule | Description | Default severity |
|------|-------------|------------------|
| `no_direct_error_logging_in_data_domain` | Forbid direct error/warning logging in the data and domain layers, where reporting is already centralised | info |
| `logger_context_must_be_structured` | Require a structured context on logger calls so log entries stay traceable and groupable | info |
| `no_sensitive_data_in_log_metadata` | Forbid tokens, passwords, credentials and API keys in log metadata or log messages | info |
| `no_raw_exception_message_to_user` | Forbid raw exception messages in UI components; user-facing text must come from stable i18n codes | info |
| `no_exception_message_passthrough` | Detect raw exception strings being forwarded towards the UI instead of a stable error code | info |
| `app_exception_must_define_code` | Require every `AppException` subtype to define a stable code so the presentation layer can localise it | info |
<!-- END AUTOGENERATED:Logging & Error Governance -->

### Async & Concurrency Rules

<!-- AUTOGENERATED:Async & Concurrency Rules -->
| Rule | Description | Default severity |
|------|-------------|------------------|
| `avoid_unawaited` | Require a categorised justification comment on every `unawaited(...)` call | info |
| `avoid_unawaited_ignore_without_reason` | Require a stated reason when an unawaited-governance rule is suppressed | info |
| `avoid_async_in_provider_create` | Forbid fire-and-forget async work inside `Provider.create`, which can mutate state before the widget tree is ready | info |
| `avoid_async_wrapper_hides_unawaited` | Detect single-await async wrappers used to hide an unawaited future from the governance rule | info |
<!-- END AUTOGENERATED:Async & Concurrency Rules -->

### State Management & Lifecycle Rules

<!-- AUTOGENERATED:State Management & Lifecycle Rules -->
| Rule | Description | Default severity |
|------|-------------|------------------|
| `no_static_map_controllers` | Prevent static Maps with Controllers/Timers (memory leaks) | info |
| `mixin_no_state_ownership` | Prevent mixins from owning lifecycle resources | info |
| `uistate_must_call_super_dispose` | Ensure UiState (ChangeNotifier) calls super.dispose() | info |
| `multiprovider_order` | Enforce UiState before ViewModel in MultiProvider | info |
| `overlay_lifecycle_context_safety` | Forbid dialog and sheet builders from capturing a caller-owned controller or using the caller's BuildContext for inherited lookups | info |
<!-- END AUTOGENERATED:State Management & Lifecycle Rules -->

### Core Language Rules

<!-- AUTOGENERATED:Core Language Rules -->
| Rule | Description | Default severity |
|------|-------------|------------------|
| `enforce_final_variables` | Prefer `final` over `var` for immutable variables | info |
| `no_late_keyword` | Avoid `late` keyword except for justified DI cases | info |
| `no_bang_operator` | Discourage null assertion operator (`!`) usage | info |
<!-- END AUTOGENERATED:Core Language Rules -->

### Code Organization Rules

<!-- AUTOGENERATED:Code Organization Rules -->
| Rule | Description | Default severity |
|------|-------------|------------------|
| `method_order` | Enforce method order: getters/setters → @override → public → private | info |
| `variable_name_should_contain_class_name` | Prevent generic variable names for complex types | info |
| `one_class_per_file` | Promote one public class per file | info |
<!-- END AUTOGENERATED:Code Organization Rules -->

### Flutter-Specific Rules

<!-- AUTOGENERATED:Flutter-Specific Rules -->
| Rule | Description | Default severity |
|------|-------------|------------------|
| `avoid_hardcoded_strings` | Detect hardcoded UI strings, suggest i18n | info |
| `viewmodels_no_buildcontext` | Prevent BuildContext usage in ViewModels | info |
<!-- END AUTOGENERATED:Flutter-Specific Rules -->

### Design Token Rules

<!-- AUTOGENERATED:Design Token Rules -->
| Rule | Description | Default severity |
|------|-------------|------------------|
| `no_hardcoded_color_literal` | Forbid raw `Color(0x...)` literals in presentation; use a design token or the theme colour scheme | info |
| `no_hardcoded_border_radius` | Forbid raw border-radius literals in presentation; use a spacing token | info |
<!-- END AUTOGENERATED:Design Token Rules -->

### Development & Testing Rules

<!-- AUTOGENERATED:Development & Testing Rules -->
| Rule | Description | Default severity |
|------|-------------|------------------|
| `no_local_datetime_constructors` | Discourage local DateTime constructors, suggest Clock injection | info |
| `no_direct_internet_calls` | Prevent direct HTTP calls outside infrastructure layer | info |
| `enforce_utc_dates` | Ensure DateTime operations use UTC | info |
| `require_keys_in_lists` | Require keys in ListView and similar widgets | info |
| `logger_context_matches_scope` | Match configured logger context to its enclosing scope | info |
<!-- END AUTOGENERATED:Development & Testing Rules -->

The table severities come from live rule codes. Override them with
`analyzer.errors`; `custom_lint.rules` controls selection and rule options.

Each rule has a document under [`docs/rules/`](docs/rules/) with rationale and examples. Some of
those documents are written in Spanish.

## How reusable each rule is

Not all of these are equally portable, and pretending otherwise would waste your time.

**Generic.** Applies to any Dart or Flutter project: `enforce_final_variables`,
`no_late_keyword`, `no_bang_operator`, `streamcontroller_must_close`, `require_keys_in_lists`,
the unawaited-governance group, and `no_sensitive_data_in_log_metadata`.

**Convention-dependent.** Enforces a particular Clean Architecture and MVVM setup and expects
base types named `BaseViewModel`, `BaseUseCase`, `UiState` and `AppException`. Useful if you
adopt that structure, noise if you do not: `viewmodels_extend_base_viewmodel`,
`usecases_extend_base_usecase`, `uistate_must_call_super_dispose`,
`app_exception_must_define_code`, `top_level_screens_must_use_base_contract`.

**Generalized from a specific failure.** The timezone rules started as a fix for one product's
regression and were made configurable so they transfer.

## Test coverage

Start with the [canonical runnable architecture example](examples/architecture/README.md).
Its original sources compile, execute, and are checked with all 48 selected rules.
The [51-rule documentation matrix](docs/example_coverage.md) identifies each
rule-local sketch separately; green labels in those sketches are not full-profile
acceptance claims. Untested full-profile source/snippet declarations fail checks.

Stated plainly, because the alternative is a claim that falls apart when someone opens `test/`.

The suite includes timezone, presentation-boundary and overlay regressions plus
resolved fixtures for final bindings, inferred resources, stream ownership and
cleanup exits, selective typing, time scopes, logger configuration, stable-key
guidance and strict naming/method order. Configuration tests cover all 51
registrations and parse generated profiles with the installed custom_lint version.
This does **not** claim behavior coverage of every rule. See
[contracts and analysis limits](docs/configuration.md).

## Installation

```yaml
dev_dependencies:
  custom_lint: ^0.8.1
  dart_architecture_lints:
    git:
      url: https://github.com/Gaan21/dart-architecture-lints.git
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

Copy [`analysis_options.yaml.template`](analysis_options.yaml.template) to choose rules and
options after reviewing its architecture assumptions. Other explicit selections
are in [`profiles/`](profiles/). Rule options use sibling keys in custom_lint 0.8.1;
see the [configuration guide](docs/configuration.md) before editing the sample.

```bash
dart run custom_lint
```

## Development

[![CI](https://github.com/Gaan21/dart-architecture-lints/actions/workflows/ci.yml/badge.svg)](https://github.com/Gaan21/dart-architecture-lints/actions/workflows/ci.yml)

```bash
dart pub get
dart analyze
dart test
dart run tool/generate_rule_tables.dart   # regenerates the tables above
dart run tool/generate_rule_tables.dart --check
dart run tool/generate_rule_tables.dart --check --guidance-root PATH
dart run tool/generate_rule_tables.dart --check --export-contract CONTRACT.json
dart run tool/generate_rule_tables.dart --verify-contract CONTRACT.json
```

The generator instantiates the plugin's `getLintRules` as the source of truth and
requires exact catalogue membership. CI checks all generated selections and tables.
README total/section markers must each have exactly one ordered pair. For exact
source/options/severity pairing with guidance, see [contract schema 1](docs/paired_contract.md).

## About this repository

This is a curated distribution of lint rules I maintain as part of my engineering workflow.
Rules are added when a defect or a repeated review comment justifies one, not on a schedule.

MIT licensed. See [LICENSE](LICENSE).

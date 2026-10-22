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
approved-wrapper configuration and glob filtering. Options are documented per rule:
[`no_utc_time_format_without_empresa_helper`](docs/rules/no_utc_time_format_without_empresa_helper.md),
[`no_civil_utc_mix_without_helper`](docs/rules/no_civil_utc_mix_without_helper.md) and
[`no_device_local_in_presentation`](docs/rules/no_device_local_in_presentation.md).

## Disable a rule

Every rule is enabled by default. There are no presets: keep the rules that fit
your project and disable the others, one by one, in the `analysis_options.yaml`
of the package being analyzed. Each rule's "Disable if" column and document say
when that is reasonable.

```yaml
analyzer:
  plugins:
    - custom_lint
  errors:
    method_order: warning
custom_lint:
  rules:
    - domain_entities_must_use_freezed: false
    - require_explicit_types: true
      policy: selective
```

With custom_lint 0.8.1, `custom_lint.rules` is a **list**. `- rule_name: false`
disables a rule; options are sibling keys in the same list entry (a nested
options map is not read). Severity overrides go under `analyzer.errors`, not in
`custom_lint.rules`. A test parses this exact example with the installed
custom_lint parser. Record approved deviations in the project's own agent
instructions so agents do not follow a rule the project disabled. See
[configuration details](docs/configuration.md) for the rules with options.

## The rule set

The tables below are generated from the plugin's registrations and
[`tool/rule_metadata.json`](tool/rule_metadata.json), and checked in CI.

<!-- AUTOGENERATED:RULE_TOTAL_COUNTS -->
**Total**: **52 registered rules**, all enabled by default. Severity is the actual LintCode default, before `analyzer.errors` overrides.
<!-- END AUTOGENERATED:RULE_TOTAL_COUNTS -->

### Timezone Safety Rules

<!-- AUTOGENERATED:Timezone Safety Rules -->
| Rule | Detects | Disable if | Default severity |
|------|---------|------------|------------------|
| [`no_device_local_in_presentation`](docs/rules/no_device_local_in_presentation.md) | `DateTime.toLocal()` calls in presentation files | Device-local time is the intended display zone for your app | info |
| [`no_civil_utc_mix_without_helper`](docs/rules/no_civil_utc_mix_without_helper.md) | Civil-date and UTC-instant values combined in one risky expression without an approved helper | Your code has no separate civil-date values, or no such mapping folders | info |
| [`no_utc_time_format_without_empresa_helper`](docs/rules/no_utc_time_format_without_empresa_helper.md) | Time-pattern formatting of a value not wrapped by an approved company-time helper | Your app displays times in UTC or the device zone by design | info |
<!-- END AUTOGENERATED:Timezone Safety Rules -->

### Architecture & Patterns Rules

<!-- AUTOGENERATED:Architecture & Patterns Rules -->
| Rule | Detects | Disable if | Default severity |
|------|---------|------------|------------------|
| [`usecases_follow_pattern`](docs/rules/usecases_follow_pattern.md) | Concrete `*UseCase` classes without their own `execute()` returning `Result` | Your use cases use another entry point (`call`, a command object) | info |
| [`viewmodels_call_super_dispose`](docs/rules/viewmodels_call_super_dispose.md) | `dispose()` in view-model-like classes that never calls `super.dispose()` | Never for `ChangeNotifier`-based view models | info |
| [`no_external_dependencies_in_domain`](docs/rules/no_external_dependencies_in_domain.md) | Imports of framework, network, storage, platform or state packages in domain files | Your domain layer deliberately depends on one of these packages | info |
| [`no_result_throw`](docs/rules/no_result_throw.md) | `throw`/`rethrow` that can escape use-case or repository methods | Your use cases/repositories intentionally propagate exceptions | info |
| [`viewmodels_no_flutter_types`](docs/rules/viewmodels_no_flutter_types.md) | Flutter UI types declared as fields of `*ViewModel*` classes | Your view models deliberately hold Flutter UI objects | info |
| [`domain_entities_must_use_freezed`](docs/rules/domain_entities_must_use_freezed.md) | Concrete public domain entity/value-object classes without `@freezed` | The project does not use Freezed for domain values | info |
| [`domain_values_shallow_immutable`](docs/rules/domain_values_shallow_immutable.md) | Mutable instance fields and public setters in domain entities/value objects | Your domain values are deliberately mutable | info |
| [`no_serialization_in_entities`](docs/rules/no_serialization_in_entities.md) | `fromJson`/`toJson` members or JSON annotations on domain entities/value objects | Your domain types intentionally double as wire models | info |
| [`models_must_have_json_serialization`](docs/rules/models_must_have_json_serialization.md) | Data models without `fromJson` + `toJson` or a JSON/Freezed annotation | Your models use another codec, or some models are not serialized | info |
| [`usecases_extend_base_usecase`](docs/rules/usecases_extend_base_usecase.md) | Concrete `*UseCase` classes under `/domain/useCases/` not extending `BaseUseCase` | Your use cases do not share a `BaseUseCase` | info |
| [`viewmodels_extend_base_viewmodel`](docs/rules/viewmodels_extend_base_viewmodel.md) | Concrete `*ViewModel` classes under `/presentation/viewModels/` not extending a base view model | Your view models do not share `BaseViewModel` | info |
| [`repository_methods_return_result`](docs/rules/repository_methods_return_result.md) | Public repository operations not returning `Result` (sync, Future, FutureOr or Stream) | Your repositories use another failure protocol | info |
| [`streamcontroller_must_close`](docs/rules/streamcontroller_must_close.md) | Owned `StreamController` fields not closed on every normal `dispose` exit | Never for owned controllers; review borrowed ones instead | info |
| [`require_explicit_types`](docs/rules/require_explicit_types.md) | Missing type annotations (strict: fields, locals, loops; selective: public boundaries) | Your style relies on type inference | info |
| [`datasources_return_result`](docs/rules/datasources_return_result.md) | Public data-source operations, including interface declarations, not returning `Result` | Your data sources throw and repositories convert failures | info |
| [`no_business_logic_in_widgets`](docs/rules/no_business_logic_in_widgets.md) | Use-case/repository construction, `*UseCase.execute()` and complex filters in widget methods | Your widgets intentionally hold presentation logic beyond rendering | info |
| [`avoid_scattered_401_handling`](docs/rules/avoid_scattered_401_handling.md) | `statusCode == 401` comparisons outside `AuthInterceptor`/`AuthService` | Your auth boundary uses other class names or 401 handling is legitimately local | info |
| [`top_level_screens_must_use_base_contract`](docs/rules/top_level_screens_must_use_base_contract.md) | `*Screen` widgets built by top-level routes that do not extend a `Base*Screen` | Your project has no base-screen contract (the rule is then inactive) | info |
| [`no_domain_entities_in_presentation_ui`](docs/rules/no_domain_entities_in_presentation_ui.md) | Imports of `package:<app>/domain/entities` in screens and widgets | The project lets UI consume domain entities directly | info |
<!-- END AUTOGENERATED:Architecture & Patterns Rules -->

### Logging & Error Governance

<!-- AUTOGENERATED:Logging & Error Governance -->
| Rule | Detects | Disable if | Default severity |
|------|---------|------------|------------------|
| [`no_direct_error_logging_in_data_domain`](docs/rules/no_direct_error_logging_in_data_domain.md) | `error`/`warning` calls on `*LoggerService` in data/domain files | Your data/domain layers own their error reporting | info |
| [`logger_context_must_be_structured`](docs/rules/logger_context_must_be_structured.md) | `warning`/`error`/`critical` logger calls without a structured literal `context` | Your logger has no context argument or uses another format | info |
| [`no_sensitive_data_in_log_metadata`](docs/rules/no_sensitive_data_in_log_metadata.md) | Credential keys in log metadata and credential patterns in log messages | Never while logs may persist; only if no such logger exists | info |
| [`no_raw_exception_message_to_user`](docs/rules/no_raw_exception_message_to_user.md) | Raw exception messages (`error.message`, `e.toString()`) passed to UI text and dialogs | Your UI shows backend messages verbatim by design | info |
| [`no_exception_message_passthrough`](docs/rules/no_exception_message_passthrough.md) | Raw exception/backend messages forwarded through `??`, message-like arguments or exception constructors | Your layers intentionally forward backend messages as user copy | info |
| [`app_exception_must_define_code`](docs/rules/app_exception_must_define_code.md) | `AppException` subclasses without a `code`, and string-literal `code:` arguments | The project has no `AppException` type with stable codes | info |
<!-- END AUTOGENERATED:Logging & Error Governance -->

### Async & Concurrency Rules

<!-- AUTOGENERATED:Async & Concurrency Rules -->
| Rule | Detects | Disable if | Default severity |
|------|---------|------------|------------------|
| [`avoid_unawaited`](docs/rules/avoid_unawaited.md) | `unawaited(...)` without a valid `// unawaited-ok: <category> - <reason>` comment | Your team does not require justification for fire-and-forget futures | info |
| [`avoid_unawaited_ignore_without_reason`](docs/rules/avoid_unawaited_ignore_without_reason.md) | `// ignore:` of the unawaited rules without `// ignore-reason: <reason>` | You disabled the unawaited-governance rules | info |
| [`avoid_async_in_provider_create`](docs/rules/avoid_async_in_provider_create.md) | `unawaited(...)` directly inside a Provider `create`/`update` closure | Your provider setup never starts async work in `create` | info |
| [`avoid_async_wrapper_hides_unawaited`](docs/rules/avoid_async_wrapper_hides_unawaited.md) | Single-`await` async callbacks in `scheduleMicrotask`, `Timer.run` or `Future(...)` | You do not use the unawaited-governance rules | info |
<!-- END AUTOGENERATED:Async & Concurrency Rules -->

### State Management & Lifecycle Rules

<!-- AUTOGENERATED:State Management & Lifecycle Rules -->
| Rule | Detects | Disable if | Default severity |
|------|---------|------------|------------------|
| [`no_static_map_controllers`](docs/rules/no_static_map_controllers.md) | Static `Map` fields whose value type is a lifecycle resource | Never in Flutter UI code; only if no such caches exist | info |
| [`mixin_no_state_ownership`](docs/rules/mixin_no_state_ownership.md) | Mixin fields whose type is a lifecycle resource (controllers, timers, focus nodes) | Your mixins deliberately own and dispose resources | info |
| [`uistate_must_call_super_dispose`](docs/rules/uistate_must_call_super_dispose.md) | `dispose()` in UI-state classes that never calls `super.dispose()` | Never for `ChangeNotifier`-based UI state | info |
| [`multiprovider_order`](docs/rules/multiprovider_order.md) | `*UiState` providers listed after `*ViewModel` providers in `MultiProvider` | Your composition does not follow the UiState-before-ViewModel naming contract | info |
| [`overlay_lifecycle_context_safety`](docs/rules/overlay_lifecycle_context_safety.md) | Overlay builders that capture a caller-owned controller or use the caller's `BuildContext` | Never in Flutter UI code | info |
<!-- END AUTOGENERATED:State Management & Lifecycle Rules -->

### Core Language Rules

<!-- AUTOGENERATED:Core Language Rules -->
| Rule | Detects | Disable if | Default severity |
|------|---------|------------|------------------|
| [`enforce_final_variables`](docs/rules/enforce_final_variables.md) | Local `var` bindings that are never reassigned | Your style prefers `var` for locals regardless of reassignment | info |
| [`no_late_keyword`](docs/rules/no_late_keyword.md) | `late` variables, except `late final` dependency-injection holders | Your team accepts `late` with reviewed initialization guarantees | info |
| [`no_bang_operator`](docs/rules/no_bang_operator.md) | Every postfix null assertion `!` | The project accepts `!` after reviewed nullability guarantees | info |
<!-- END AUTOGENERATED:Core Language Rules -->

### Code Organization Rules

<!-- AUTOGENERATED:Code Organization Rules -->
| Rule | Detects | Disable if | Default severity |
|------|---------|------------|------------------|
| [`method_order`](docs/rules/method_order.md) | Class methods out of order: getters/setters, `@override`, public, private | Your style guide uses a different member order | info |
| [`variable_name_should_contain_class_name`](docs/rules/variable_name_should_contain_class_name.md) | Variables of a class type whose name does not contain the class name | Your naming convention allows short or role-only names | info |
| [`one_class_per_file`](docs/rules/one_class_per_file.md) | More than one public class, enum or mixin per file | Your style allows cohesive type families in one file | info |
<!-- END AUTOGENERATED:Code Organization Rules -->

### Flutter-Specific Rules

<!-- AUTOGENERATED:Flutter-Specific Rules -->
| Rule | Detects | Disable if | Default severity |
|------|---------|------------|------------------|
| [`avoid_hardcoded_strings`](docs/rules/avoid_hardcoded_strings.md) | String literals in presentation and use-case files that look like user-facing text | The project does not localize, or localizes outside these layers | info |
| [`viewmodels_no_buildcontext`](docs/rules/viewmodels_no_buildcontext.md) | `BuildContext` fields or constructor parameters in view models | Never in MVVM code; only if view models intentionally own UI context | info |
<!-- END AUTOGENERATED:Flutter-Specific Rules -->

### Design Token Rules

<!-- AUTOGENERATED:Design Token Rules -->
| Rule | Detects | Disable if | Default severity |
|------|---------|------------|------------------|
| [`no_hardcoded_color_literal`](docs/rules/no_hardcoded_color_literal.md) | `Color(0x...)` hex literals in presentation files | The project has no color tokens or theme color scheme | info |
| [`no_hardcoded_border_radius`](docs/rules/no_hardcoded_border_radius.md) | `BorderRadius.circular` with literal 6, 12 or 16 (values with a spacing token) | The project has no `AppSpacing` radius tokens | info |
<!-- END AUTOGENERATED:Design Token Rules -->

### Development & Testing Rules

<!-- AUTOGENERATED:Development & Testing Rules -->
| Rule | Detects | Disable if | Default severity |
|------|---------|------------|------------------|
| [`no_local_datetime_constructors`](docs/rules/no_local_datetime_constructors.md) | `DateTime.now()`, local `DateTime(...)`, non-UTC epoch and unconverted `parse` | Your project accepts device-local clocks and dates throughout | info |
| [`no_direct_internet_calls`](docs/rules/no_direct_internet_calls.md) | HTTP client construction/calls and connectivity checks outside network service files | Your app has no central network service | info |
| [`enforce_utc_dates`](docs/rules/enforce_utc_dates.md) | Non-UTC `DateTime` construction or parsing in data-layer files | Data-layer timestamps are deliberately local or civil dates | info |
| [`require_keys_in_lists`](docs/rules/require_keys_in_lists.md) | Keyless widgets returned directly by `ListView.builder`/`GridView.builder` item builders | Your lists are static or items never move | info |
| [`logger_context_matches_scope`](docs/rules/logger_context_matches_scope.md) | Literal log `context:` values that differ from `Type.member` of the enclosing member | Your log context is not a `Type.member` string | info |
<!-- END AUTOGENERATED:Development & Testing Rules -->

Each rule has a short document under [`docs/rules/`](docs/rules/): what it
detects, why, one bad/good example, when to disable it, options and limits.
Diagnostic messages of some older rules are still written in Spanish.

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
Its original source compiles, executes, and passes every registered rule with
default options. The [documentation matrix](docs/example_coverage.md) lists each
rule-local sketch separately; GOOD labels in those sketches are not claims that
the snippet passes every rule. Undeclared all-rules snippets fail the checks.

Stated plainly, because the alternative is a claim that falls apart when someone opens `test/`.

The suite includes timezone, presentation-boundary and overlay regressions plus
resolved fixtures for final bindings, inferred resources, stream ownership and
cleanup exits, selective typing, time scopes, logger configuration, stable-key
guidance, strict naming/method order, Result return/throw scopes and shallow
domain-value immutability. Configuration tests cover every registration, the
default-enabled contract and the README disable example. This does **not** claim
behavior coverage of every rule.

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

All rules then run. Disable the ones that do not fit, as shown in
[Disable a rule](#disable-a-rule). Updating this dependency does not change your
configuration; review new rules and diagnostics before accepting an update.

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
```

The generator uses the plugin's `getLintRules` as the source of truth, requires
metadata for exactly the registered rules, requires every rule to be enabled by
default, and checks that each rule document uses the uniform format with the
live default severity. README markers must each have exactly one ordered pair.

Maintainers: [deferred guidance alignment](docs/deferred-guidance-alignment.md)
records completed and pending guidance/lint alignment and the required
bidirectional impact review with the common guidance in
[agent-guides](https://github.com/Gaan21/agent-guides).

## About this repository

This is a curated distribution of lint rules I maintain as part of my engineering workflow.
Rules are added when a defect or a repeated review comment justifies one, not on a schedule.

MIT licensed. See [LICENSE](LICENSE).

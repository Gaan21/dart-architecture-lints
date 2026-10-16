# Selecting an architecture and style contract

The plugin registers 51 rules. Without explicit selections, every rule remains
enabled with its existing default contract. No profile is applied automatically.
Copy and review a generated sample in your own project:

| Sample | Explicit selection |
|--------|--------------------|
| `profiles/legacy.yaml` | All 51 enabled; strict variable annotations and existing time/logging scopes |
| `profiles/architecture.yaml` / `analysis_options.yaml.template` | 48 of 51 enabled; selective typing and portable logger scope options |
| `profiles/style.yaml` | Four style rules enabled; all other rules explicitly disabled |

The architecture sample retains strict `variable_name_should_contain_class_name`
and `method_order`. Selective typing does not relax either rule. The style sample
is a deliberate reduced contract for new adopters, not a migration to apply over
an existing architecture contract. Merge reviewed selections instead of replacing
an existing project's configuration wholesale.

The architecture recommendation explicitly deselects only `no_late_keyword`,
`no_bang_operator` and `one_class_per_file`: approved exceptions to blanket
language restrictions, not a weakening of architecture/resource contracts.
`no_static_map_controllers` and `mixin_no_state_ownership` remain selected.
All three deselected language rules remain available for explicit opt-in and
remain enabled in legacy/default configurations. The style sample retains strict
naming, method order, selective types and final-binding checks, without a blanket
one-class-per-file restriction. The architecture alias and template are generated
from the same selections; neither is separately maintained.

## Actual custom_lint syntax and severity

For custom_lint 0.8.1, `rules` is a **list**. Options are sibling keys in the
same list entry, after its rule key. A nested options map is not consumed by this
version's parser. The configuration tests exercise the real parser.

```yaml
analyzer:
  plugins:
    - custom_lint
  errors:
    method_order: warning
custom_lint:
  enable_all_lint_rules: false
  rules:
    - method_order: true
    - variable_name_should_contain_class_name: true
    - require_explicit_types: true
      policy: selective
      local_names: ["*Boundary", "payload"]
```

`enable_all_lint_rules: false` disables only unlisted rules; explicit `true`
entries remain enabled. It does not disable the plugin. A `false` entry disables
that individual rule. Severity overrides belong in `analyzer.errors`, not values
such as `rule_name: warning` under `custom_lint.rules`.

README tables report the registered `LintCode` severity, not a recommended
severity inferred from a sample. Selection and severity are independent.
`dart run custom_lint` 0.8.1 defaults to fatal warnings **and fatal infos**.
Use `--no-fatal-infos` or `--no-fatal-warnings` only as an intentional CI policy.

## Selective explicit types

`require_explicit_types` options:

* `policy: strict` (default): preserves checks on every field, local declaration
  and supported loop declaration. It does not add signature checks to legacy mode.
* `policy: selective`: requires annotations on public fields and top-level
  variables, public method/getter and top-level function return types, and simple
  public method, constructor and top-level function parameters. Setter returns
  are excluded. Initializing/super formals inherit their declared field/parent
  types. Private classes and private declarations are excluded from public checks.
* `local_names`: wildcard patterns selecting local names that need an annotation
  in selective mode. An inferred `dynamic` local also requires an annotation.
  Other inferred locals and loop variables are allowed. This is an explicit
  boundary policy, not an attempt to infer a human reader's idea of complexity.

Anonymous callbacks and local functions are not public API parameters. Extension
and mixin public members are checked by member name; this is not a complete
export-reachability analysis. Upstream `always_declare_return_types` can extend
signature checking to private functions if your project wants it. See the
[official Dart lint catalogue](https://dart.dev/tools/linter-rules).

## Time scopes

Both `enforce_utc_dates` and `no_local_datetime_constructors` accept:

* `include_globs`: default `["**"]`; the UTC rule also retains its data-layer
  segment filter (`data`, `datasource(s)`, `repository/repositories`,
  `infrastructure`, `models`, `entities`). An include does not expand that filter.
* `exclude_globs`: default `[]`; skips that rule in matched files.
* `civil_date_globs`: default `[]`; allows the unnamed `DateTime(year, ...)`
  constructor in those files. It does not permit direct clocks or ambiguous parse.
* `clock_globs`: default `[]`; allows `DateTime.now()` in explicit clock adapters.
  Other local constructors remain checked.

```yaml
custom_lint:
  rules:
    - no_local_datetime_constructors: true
      civil_date_globs: ["**/calendar_values.dart"]
      clock_globs: ["**/clock_adapter.dart"]
    - enforce_utc_dates: true
      civil_date_globs: ["**/calendar_values.dart"]
```

Scope exceptions are file-level ownership decisions, not proof of correct
calendar/timezone modeling. Epoch getters are zone-independent. Explicit ISO
offsets and `Z` parse to UTC; ambiguous parses still require conversion. These
construction checks do not prove arbitrary variables are UTC. The separate civil
mix, device-local presentation and organization-zone formatting rules remain
registered, selected and effective under legacy and architecture selections.

## Logger scope portability

`logger_context_matches_scope` accepts `include_globs`, `exclude_globs`,
`logger_names` (wildcards matching receiver names or resolved type display names),
`methods` (default `[error, warning]`), and `context_argument` (default `context`).
Omitting the include/name options retains the legacy built-in scope and receiver
matching. Providing them replaces those defaults. An empty list matches nothing.
The architecture sample uses generic `Logger`/`logger` receivers in `lib`;
configure the names your logging abstraction actually exposes.

Only literal context arguments with an identifiable enclosing named member are
checked. Context is `Type.member`, stripping one leading underscore and a trailing
`Internal` from the member. Unnamed constructors and top-level functions are
skipped. This checks scope consistency, not whether errors were logged safely;
the other logging/error rules retain their own contracts.

## Contract-dependent rules and UI scope

`multiprovider_order` is still enabled by default and in the architecture sample.
It enforces the naming contract: `*UiState` before `*ViewModel` in a direct
`MultiProvider.providers` list. It is not a dependency-graph solver. Spread lists
are skipped; unrelated provider types are not ordered. Review actual dependencies
even when the naming contract passes. Projects adopting a different composition
model may explicitly deselect it.

`require_keys_in_lists` checks direct expression-bodied item-builder returns for
`ListView.builder` and `GridView.builder`. It does not analyze block returns,
helper-built widgets, conditional returns, or whether a supplied key is stable.
Use identity-based stable keys when items move; an index is unsuitable for
reordered data. A fresh `UniqueKey` loses continuity and keys do not prevent
rebuilds. Color, radius, widget/business-logic and overlay rules are independent;
their selection is unchanged in the architecture sample.

## Resource checks and limits

Resource checks use resolved inferred field types. Static maps and mixins still
detect their supported resource families when field type annotations are omitted.
Stream cleanup is per owned field, including multiple variables in a declaration.
It tracks normal exits through blocks, branches, returns, conservative loop paths,
try/catch/finally and resolved same-instance local helper methods. Asynchronous
helpers must be awaited to establish cleanup. Local shadowing cannot close a field.

The stream rule retains its view-model path/base-class scope (including resolved
indirect bases). Field and constructor initializers establish local ownership;
simple identifier/property initializers and constructor-injected fields are treated
as borrowed/unknown. Resource factories are conservatively treated as owned.
Inherited resources are checked at their declaring class. Inherited cleanup helper
bodies, alias transfer, late assignments, cascades and arbitrary control flow are
not proved. Unsupported paths may conservatively report; review ownership rather
than adding unsafe disposals. This is not whole-program leak analysis and does not
prove asynchronous close completion or ordering before `super.dispose()`.

`enforce_final_variables` uses resolved writes, including compound assignments,
increments and closure captures. It checks local `var` bindings, retaining loop
exceptions. Public fields/top-level bindings are not treated as immutable based
on the absence of writes in one file.

Parentheses, successful `as` casts and null assertions around reference
initializers do not transfer ownership. Borrowed stream controllers stay borrowed
through these wrappers in both field and constructor initializers; do not dispose
an external resource to silence this check.

## Deterministic alignment

```sh
dart run tool/generate_rule_tables.dart
dart run tool/generate_rule_tables.dart --check
dart run tool/generate_rule_tables.dart --check --guidance-root PATH
dart run tool/generate_rule_tables.dart --help
dart test
```

The generator instantiates the actual plugin registrations, requires exact
metadata membership and emits every selection in each sample. `--check` rejects
drift, unknown/duplicate/missing selections and unsupported rule-list syntax.
Tests verify the samples with the installed custom_lint parser and exercise
original resolved fixtures. Registration/configuration coverage of all 51 rules
does not imply behavior coverage of all 51. Every rule document declares its exact
isolated example contract. The [51-rule coverage matrix](example_coverage.md)
distinguishes those partial sketches from the [original runnable sources](../examples/architecture/README.md)
compiled and checked under all 48 selected rules. No consumer configuration is
activated by generating these files.

`--guidance-root PATH` optionally reads `PATH/profiles/architecture.md` and
compares its table with live registrations and the same architecture-selection
function used for YAML generation. It never writes to the guidance root. Use a
table headed `| Rule | Selection | ... |`; each of the 51 IDs must occur once in
the first column, backticked, with an exact `enabled` or `disabled` second cell.
Extra description columns are allowed. Duplicate, missing, unknown, malformed or
incorrect-state rows fail. Prose and fenced examples do not count as table rows.
No sibling checkout is consulted unless the option is explicitly supplied.

Diagnostic IDs come from each registered `LintCode.name`. The descriptive metadata
key is `id` in `tool/rule_metadata.json` (alongside `section`, `description`, and
optional `status`); metadata membership must exactly match registrations. These
are diagnostic IDs, not Dart implementation class names. The generated architecture
YAML inventories all 51 IDs, with 48 true and the three approved exceptions false.

For an exact guidance/linter source pairing, use the deterministic JSON exporter
and read-only verifier described in [paired contract schema 1](paired_contract.md).
Selection agreement alone does not establish package-source identity.

# Deferred guidance alignment

Owner direction recorded 2026-10-21. Items 1 and 2 were implemented on owner
authorization (unreleased; see `CHANGELOG.md`). Item 3 is a written proposal only.
Revised owner model: every rule is enabled by default and each project disables
individual rules in its own `analysis_options.yaml`; there are no profiles.
Nothing here is an approved consumer configuration change or migration instruction.

The maintained common-guidance destination is
[agent-guides](https://github.com/Gaan21/agent-guides), separate from the linter and
the Python `agent-guides-cli` delivery tool. Preserve existing consumers and legacy
delivery during the content handoff; do not make new work depend on an archive.

Standing direction: keep layers and architecture controls. Prefer existing explicit
configuration and documented, approved alternatives to a new flexibility framework.
Each rule document's "Disable if" section states when a project may turn it off;
the common guidance links this linter rather than coupling to a selection.

## Selection model: done

- Profiles, the analysis-options template and the legacy pairing tool
  (`--guidance-root`, contract export/verify) were removed; the last commit with
  them is `dc959a5`. All 52 rules are enabled by default.
- Every rule document has a "Disable if" section and the README table repeats it.
  Guidance review of a lint change now covers that statement too.

## 1. Freezed nonmandatory: done

- `domain_entities_must_use_freezed` is a Freezed convention: same ID and
  detector, enabled by default; a project that does not use Freezed disables it.
  No rename or deprecation. It never reads `pubspec.yaml`.
- New `domain_values_shallow_immutable` (enabled by default): non-final instance
  fields, public `late final` without initializer and public setters in domain
  entities/value objects. Accepts Freezed-annotated classes by spelling.
  Shallow; no deep-immutability claim.
- Pending: mutable collection exposure (`final List<T>`) is not checked because
  the declared type cannot show runtime unmodifiability; left to review/tests.

## 2. Result outcomes: done

- Repository/data-source rules share a resolved classifier: `Result` and
  `Future`/`FutureOr`/`Stream` of `Result`, including typedef aliases. Synchronous
  getters and private helpers return values directly; asynchronous getters and
  public operations, including pure ones, still need `Result`. No inference from
  names or signatures.
- `no_result_throw` exempts only throws caught by a matching clause of an
  enclosing `try` block in the same body; its document no longer claims that
  `rethrow` is allowed.
- Pending gaps (documented, not changed): repository interfaces outside
  `/data/repositories/`, `datasources`/`data_sources` folder spellings, the broad
  name-contains scope of `no_result_throw`, programmer-defect throws, extensions,
  mixins and top-level functions.

## 3. Base classes: proposal only

Pending; no detector or base-class change. Low urgency, medium importance.

| Rule | Shared behavior it protects | Detector reality |
|------|-----------------------------|------------------|
| `usecases_extend_base_usecase` | Guarded conversion of failures to `Result` (`executeGuard`) | Direct superclass named `BaseUseCase` under `/domain/useCases/` |
| `viewmodels_extend_base_viewmodel` | Typed UI state, `handleResult`, disposed-state guard | Direct superclass `BaseViewModel`/`BaseViewModelWithEffects` |
| `top_level_screens_must_use_base_contract` | Shared screen chrome/analytics/lifecycle hooks | Active only if `screens/base/` exists; regex scan, `Base*Screen` names, fixed exception names |

Official [Flutter recommendations](https://docs.flutter.dev/app-architecture/recommendations)
strongly recommend MVVM, logic out of widgets and immutable models; ChangeNotifier
and a domain layer/use cases are conditional, and Commands are recommended. They
do not prescribe base classes. A base class is one valid way to share the
behavior above; composition (mixins, a Command/guard helper) is another.

Proposal:

1. Keep all three rules enabled by default; existing bases stay authoritative and
   projects without such bases disable them (see each "Disable if").
2. Document each rule as a project contract (protected behavior, not "Flutter
   requires a base class"), as the common guidance already states.
3. If an approved project needs it, add an option listing accepted base names and
   resolve supertypes (indirect bases), preserving current defaults.
4. Replace the fixed screen exception names with a configurable list, keeping
   today's list as the default. Each option needs focused tests and a separate
   owner decision; no consumer migration is implied.

## Required bidirectional change review

Priority: low urgency and medium importance for the deferred detector/base-class
work. Cross-package consistency review has high importance whenever either side
changes. Do not implement changes merely to complete the content handoff.

Every added, changed or deleted guide requires review of affected lint IDs and
whether useful new detection is feasible. Every added, changed, renamed or removed
lint/option requires review of corresponding written obligations and exceptions.

Record actual predicate/scope, limitations, options/defaults, compatibility effects,
tests and residual behavioral review. Removing a detector does not delete policy;
removing prose must not leave an unexplained mandatory detector. Distinguish detector
repair from a new obligation. Preserve exact shared candidate identities and obtain
separate authorization before activating changes in consumers.

Companion roadmap: [guidance follow-up](https://github.com/Gaan21/agent-guides/blob/develop/docs/deferred-improvements.md).
Official references: [Flutter recommendations](https://docs.flutter.dev/app-architecture/recommendations)
and [Result pattern](https://docs.flutter.dev/app-architecture/design-patterns/result).

## Pending after the 0.1.0 plugin port

- Verify the `git: url/ref` plugin source end to end from a consumer (only the
  `path:` source was exercised before publishing).
- `avoid_unawaited_ignore_without_reason`: its correction message still shows the
  bare `// ignore: avoid_unawaited` example; update it to the prefixed form.
- Rule constructors keep option parameters used only by tests; remove them if
  options stay fixed.

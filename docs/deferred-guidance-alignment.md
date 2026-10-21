# Deferred guidance alignment

Owner direction recorded 2026-10-21. Low-priority proposals, not implemented
detectors, approved consumer configuration changes or a migration instruction.

The maintained common-guidance destination is
[agent-guides](https://github.com/Gaan21/agent-guides), separate from the linter and
the Python `agent-guides-cli` delivery tool. Preserve existing consumers and legacy
delivery during the content handoff; do not make new work depend on an archive.

## Follow-up candidates

- Keep layers and architecture controls. Prefer existing explicit configuration
  and documented, approved alternatives to a new flexibility framework.
- Make Freezed nonmandatory in common guidance. First assess inexpensive checks
  for the underlying immutable-value requirements. Do not claim that annotations,
  final fields or shallow checks prove deeply immutable values. If equivalent
  detection is too costly, propose an optional convention with bounded checks
  where actually selected; installing a dependency is not class-level selection.
- Preserve Result-style domain-operation outcomes. Review signature/throw check
  scopes, supported types and gaps with focused positive/negative tests. Owner
  accepted: public domain operations return Result; infallible getters/internal
  calculations return direct values. Purity alone does not imply infallibility.
  This direction does not activate detector or consumer configuration changes.
- Review base-class requirements against actual shared behavior and official
  Flutter recommendations before proposing alternatives. No architecture rewrite
  or source-compatible migration is assumed.

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

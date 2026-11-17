# Opt-in unawaited permissions (v1)

Await work when the next step depends on the outcome, including a returned
failure value. A detached call needs human review of why it does not wait, who
handles failure and what happens if the work completes late.

`avoid_unawaited` defaults to its previous comment-based behavior. Set this
explicit top-level key in the nearest package's `pubspec.yaml` to switch modes:

```yaml
dart_architecture_lints_unawaited_permissions: config/unawaited.json
```

Keep `avoid_unawaited` enabled. The value is a package-relative JSON file path.
The file is an object with `version: 1` and a `permissions` array (which may be
empty). Each entry has six nonblank strings: `path`, `scope`, `fingerprint`,
`whyDetached`, `failureOwner`, `lateCompletion`. `path` is package-relative
with forward slashes. Absolute paths, traversal, generated sources and
duplicate selectors are rejected.

`path`, `scope` and `fingerprint` together select exactly one direct invocation.
`scope` is the slash-separated chain of recognized named declarations (or
`<unit>`); anonymous callbacks do not add a scope. `fingerprint` is lowercase
SHA-256 of a UTF-8 JSON array of the invocation's Dart token lexemes. Whitespace,
comments and trailing commas before closing delimiters are omitted. Identical
invocations in the same scope are ambiguous: neither is permitted. Line numbers
and occurrence indices are not identities. A changed expression or named
scope needs review; the selector does not attest to the method body's behavior
or establish provenance if a call is removed and replaced by the same syntax.

From a checkout of this plugin at the same revision as the analyzed plugin:

```sh
dart pub get
dart run bin/unawaited_permissions.dart list /path/to/package lib/example.dart
dart run bin/unawaited_permissions.dart verify /path/to/package
(cd /path/to/package && dart analyze --fatal-infos)
```

Resolve the target package's dependencies first (`flutter pub get` for Flutter).
`list` prints one JSON record per detected call for review, including the full
source expression. It does not grant permission. `verify` exits nonzero if the
manifest is invalid or any entry matches other than exactly one call, including
in missing or unresolved files. Run it **alongside** native analysis, which
checks unapproved calls and stale entries in files that are actually analyzed.
An IDE may need an analysis restart after a manifest-only edit.

## Boundaries

- In manifest mode only direct, resolved `dart:async` `unawaited` invocations
  are matched, including prefixed calls. An inline `unawaited-ok` never grants
  permission. Generated and excluded files are not linted.
- Keep `discarded_futures`, `unawaited_futures`, `avoid_async_in_provider_create`
  and `avoid_async_wrapper_hides_unawaited` enabled. The wrapper lint detects
  the documented single-statement `await` forms in `scheduleMicrotask`,
  `Timer.run` and the unnamed `Future` constructor. Neither check is a
  whole-program proof: aliases, `.ignore()`, other wrappers, multi-statement
  callbacks, or async `void` boundaries can hide work. Review the actual
  failure owner and late-result behavior; no ignore or exclusion is permission.
- The manifest is editable project data, not an approval service. A trusted
  reviewer must compare the candidate with the manifest **and activation
  configuration** from an independently selected approved base revision,
  and review additions/changes under the host's existing approval mechanism.
  Analyzing against the candidate's own manifest cannot establish approval.

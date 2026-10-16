# Paired architecture identity

Export from the checkout whose plugin/source is being paired with guidance:

```sh
dart run tool/generate_rule_tables.dart --check --export-contract CONTRACT.json
dart run tool/generate_rule_tables.dart --check --guidance-root GUIDANCE_ROOT --export-contract CONTRACT.json
dart run tool/generate_rule_tables.dart --verify-contract CONTRACT.json
```

Export/verify imply checking generated files: they do not regenerate the checkout.
An explicit export writes only its requested artifact. Its parent must exist.
Verification reads the artifact and requires exact byte equality with a fresh
export from the current source. Supplying export and verification together verifies
first; a mismatch cannot be overwritten by that invocation. Contract artifacts
should be stored outside the source inputs. No consumer is activated or changed.

## Schema 1

The JSON object has exactly these fields (object key order is canonical, not the
illustrative order below):

* `schema`: integer `1`.
* `package`: the actual `name` from `pubspec.yaml` (`dart_architecture_lints`).
* `version`: the actual version string from `pubspec.yaml` (`0.0.6`).
* `source_digest`: lowercase 64-character SHA-256 hex string, defined below.
* `profile`: string `architecture`.
* `rules`: object with every live registered diagnostic ID as a key. Each value
  has exactly `enabled` (boolean), `options` (object) and `severity` (one of
  `INFO`, `WARNING`, `ERROR`).

Rule registrations are instantiated with the checked architecture profile through
the installed custom_lint parser. Options are its actual sibling-key `json`
options, not guessed constructor defaults; rules without options use `{}`.
Severity comes from each actual `LintCode`, not a severity recommendation. The
profile currently supplies no `analyzer.errors` overrides. All 51 entries are
present, including the three disabled language restrictions.

## Canonical encoding and source digest

`canonicalJson(value)` recursively sorts object keys using Dart's string
lexicographic ordering (UTF-16 code units), preserves array order, uses compact
`jsonEncode` output (no indentation/spaces or ASCII-only escaping), then appends
**exactly one LF**. Encode that string as UTF-8 without a BOM. The schema contains
only integral numeric schema `1`; source manifests contain only strings.

1. Enumerate **all** `lib/**/*.dart` files, plus `pubspec.yaml` and
   `profiles/architecture.yaml`, relative to the source checkout.
2. Hash each file's original bytes with SHA-256, without newline normalization.
3. Build an object mapping package-relative POSIX paths to lowercase hex hashes.
   Sort path keys as above. Do not include absolute paths, timestamps or Git state.
4. Apply `canonicalJson` to that manifest, UTF-8 encode it, and SHA-256 those bytes.
   Its lowercase hex digest is `source_digest`.

The exported contract also uses `canonicalJson` and the same one-LF UTF-8 encoding.
Library symlinks are rejected rather than silently omitting linked source.
The digest deliberately covers the shipped architecture profile and original
library code, not guidance, test/example files, tool implementation or a moving
Git revision. A source or profile byte change changes identity.

## What the comparison establishes

This artifact self-attests the source checkout used by the exporter. Hashes
establish integrity, **not publisher trust**. Exporting here does not prove that a
consumer application installed this package, this version, or this profile.
Before accepting a pair for a consumer task, independently locate its actual
resolved source, compare that source's manifest digest and the applicable
registration/profile contract, and record the matched artifact with guidance.
Do not resolve a different/latest revision to make a mismatch disappear.

The read-only guidance table check verifies IDs and selections only. The JSON
pair additionally binds options, severities and source bytes. The exporter does
not inspect a consumer lockfile, perform dependency installation, or activate a
profile on behalf of the consumer.

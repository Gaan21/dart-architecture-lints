<!-- example-scope: isolated no_domain_entities_in_presentation_ui -->

> **Example contract: `no_domain_entities_in_presentation_ui` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_domain_entities_in_presentation_ui

**Default severity**: info. Enabled by default.

## What it detects

Import directives whose URI is `package:<package>/domain/entities.dart` or starts with `package:<package>/domain/entities/`, where `<package>` is the analyzed package, in files matching the include globs and not the allowed files.

## Why

Presentation models decouple widgets from domain changes; mapping stays in explicit UI mapper files.

## Example

```dart
// BAD
import 'package:my_app/domain/entities/user.dart';
```

```dart
// GOOD
import 'package:my_app/presentation/models/user_ui_model.dart';
```

## Disable if

Your UI uses domain entities directly by design.

## Options

Fixed since 0.1.0 (the analyzer plugin API has no rule options): the package name is the `name` in the nearest `pubspec.yaml` above the file; include globs `**/lib/presentation/screens/**`, `**/lib/presentation/widgets/**`; allowed files `**/lib/presentation/**/*_ui_mapper.dart`.

## Limits

- Only `package:` imports with the analyzed package name; relative imports, exports and transitive use are not detected.
- Entities imported from another package (for example a shared domain package) are not checked.

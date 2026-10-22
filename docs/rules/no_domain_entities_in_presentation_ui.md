<!-- example-scope: isolated no_domain_entities_in_presentation_ui -->

> **Example contract: `no_domain_entities_in_presentation_ui` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_domain_entities_in_presentation_ui

**Default severity**: info. Enabled by default.

## What it detects

Import directives whose URI is `package:<package>/domain/entities.dart` or starts with `package:<package>/domain/entities/`, where `<package>` is the analyzed package (or `project_package_name`), in files matching `include_globs` and not `allowed_file_globs`.

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

Sibling keys: `project_package_name` (default: the analyzed package's own name, taken from the library's `package:` URI or else the project's `pubspec.yaml`; set it to check another package name), `include_globs` (default `**/lib/presentation/screens/**`, `**/lib/presentation/widgets/**`) and `allowed_file_globs` (default `**/lib/presentation/**/*_ui_mapper.dart`).

## Limits

- Only `package:` imports with the configured name; relative imports, exports and transitive use are not detected.
- Entities imported from another package (for example a shared domain package) are only checked when `project_package_name` names it.

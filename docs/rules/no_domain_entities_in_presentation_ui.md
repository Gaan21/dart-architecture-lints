<!-- example-scope: isolated no_domain_entities_in_presentation_ui -->

> **Example contract: `no_domain_entities_in_presentation_ui` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_domain_entities_in_presentation_ui

**Default severity**: info. Enabled by default.

## What it detects

Import directives whose URI is `package:<project_package_name>/domain/entities.dart` or starts with `package:<project_package_name>/domain/entities/`, in files matching `include_globs` and not `allowed_file_globs`.

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

Sibling keys: `project_package_name` (default `work_tracker`; set it to your package name, otherwise nothing matches), `include_globs` (default `**/lib/presentation/screens/**`, `**/lib/presentation/widgets/**`) and `allowed_file_globs` (default `**/lib/presentation/**/*_ui_mapper.dart`).

## Limits

- Only `package:` imports with the configured name; relative imports, exports and transitive use are not detected.
- The historical default package name rarely matches a new project, so configure it.

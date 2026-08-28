# no_domain_entities_in_presentation_ui

## Purpose

Prevent architectural coupling from Presentation UI to Domain Entities.

This rule reports imports of:

- `package:work_tracker/domain/entities/entities.dart`
- `package:work_tracker/domain/entities/*`

when used inside:

- `lib/presentation/screens/**`
- `lib/presentation/widgets/**`

Rationale: UI should depend on `presentation/models/*_ui_model.dart` contracts, not on domain entities directly.

## Violation Message

`Presentation UI must not depend on domain entities directly; use UiModel contracts from presentation/models.`

## FAIL

```dart
import 'package:work_tracker/domain/entities/entities.dart';

class WorkerDashboardScreen {}
```

```dart
import 'package:work_tracker/domain/entities/worker_entity.dart';

class WorkerTile {}
```

## PASS

```dart
import 'package:work_tracker/presentation/models/worker_ui_model.dart';

class WorkerDashboardScreen {}
```

```dart
import 'package:work_tracker/domain/entities/incidencia_entity.dart';

class IncidenciasUiMapper {}
```

`*_ui_mapper.dart` files under `presentation/` are explicitly allowlisted so mapping remains centralized.

## Allowed Exceptions (explicit)

Default allowlist:

- `**/lib/presentation/**/*_ui_mapper.dart`

You can add more explicit exceptions with `allowed_file_globs` (avoid broad wildcards).

## Configuration

```yaml
custom_lint:
  rules:
    no_domain_entities_in_presentation_ui: warning
```

Optional parameters:

```yaml
custom_lint:
  rules:
    no_domain_entities_in_presentation_ui:
      severity: warning
      project_package_name: work_tracker
      include_globs:
        - "**/lib/presentation/screens/**"
        - "**/lib/presentation/widgets/**"
      allowed_file_globs:
        - "**/lib/presentation/**/*_ui_mapper.dart"
        # Keep exceptions explicit and documented.
```

## Limitations

- This first version enforces import-level boundaries (robust, low false-positive).
- It does not yet forbid domain types in local render signatures when there is no direct import violation.
- Future enhancement: add AST checks for domain types in `presentation/screens/**` render methods.

## Testing Guide

### In this lint repository

```bash
dart test test/no_domain_entities_in_presentation_ui_test.dart
```

### In WorkTracker (local path dependency)

1. Point `dart_architecture_lints` in WorkTracker `pubspec.yaml` to local path.
2. Run:

```bash
dart run custom_lint lib/presentation/screens
dart run custom_lint lib/presentation/widgets
```

Expected:

- Violations in pending screens/widgets that still import domain entities.
- No violation in `lib/presentation/screens/incidencias/incidencias_ui_mapper.dart`.

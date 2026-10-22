<!-- example-scope: isolated no_external_dependencies_in_domain -->

> **Example contract: `no_external_dependencies_in_domain` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_external_dependencies_in_domain

**Default severity**: info. Enabled by default.

## What it detects

In files with a `domain` path segment (skipping paths with a segment containing `test`): `package:` imports of a fixed list of packages, including `flutter`, `provider`, `bloc`/`flutter_bloc`, `riverpod`, `get`, `mobx`, `dio`, `http`, `chopper`, `retrofit`, `hive`, `sqflite`, `shared_preferences`, `sembast`, `drift`, `path_provider`, `device_info(_plus)`, `permission_handler`, `package_info(_plus)`, Firebase packages, `go_router`, `auto_route`, `beamer`, `flutter_test`, `integration_test`, `logger`, `image_picker`, `camera`, `location` and `geolocator`.

## Why

The domain should depend on abstractions; infrastructure details enter through interfaces implemented in data/infrastructure.

## Example

```dart
// BAD
import 'package:dio/dio.dart';
```

```dart
// GOOD
import 'package:my_app/domain/repositories/user_repository.dart';
```

## Disable if

Your architecture has no separate domain layer, or allows a listed package there.

## Options

None. The package list is fixed.

## Limits

- Packages not in the list are not reported, even if external; `meta`, `freezed_annotation`, `json_annotation`, `equatable` and `dartz` are explicitly allowed.
- Exports, relative imports into other layers and transitive dependencies are not checked.

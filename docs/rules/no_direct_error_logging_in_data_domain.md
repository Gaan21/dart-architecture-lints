<!-- example-scope: isolated no_direct_error_logging_in_data_domain -->

> **Example contract: `no_direct_error_logging_in_data_domain` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_direct_error_logging_in_data_domain

**Default severity**: info. Enabled by default.

## What it detects

In files whose path contains `/data/` or `/domain/`: `error(...)` or `warning(...)` calls whose target is an identifier or static type named `AppLoggerService`, `appLoggerService` or ending with `LoggerService`. Files ending with `core/mixins/guard_mixin.dart`, `domain/useCases/base_use_case.dart`, `core/services/error_reporter_service.dart` or `core/services/app_logger_service.dart` are allowed.

## Why

When failures are reported centrally at a guard/error-reporter boundary, logging them again in data/domain duplicates the signal.

## Example

```dart
// BAD
catch (error) {
  AppLoggerService.error('load failed', error);
  return Result.failure(AppException.unexpected(error));
}
```

```dart
// GOOD
catch (error) {
  return Result.failure(AppException.unexpected(error));
}
```

## Disable if

Your project has no central reporting boundary, or data/domain code is expected to log errors itself.

## Options

None. The allowlisted file suffixes are fixed.

## Limits

- Logger receivers are matched by name; other logger APIs (`log`, `Logger.severe`) are not detected.
- It does not verify that the central boundary actually reports the failure.

<!-- example-scope: isolated no_sensitive_data_in_log_metadata -->

> **Example contract: `no_sensitive_data_in_log_metadata` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_sensitive_data_in_log_metadata

**Default severity**: info. Enabled by default.

## What it detects

In files under `/lib/`, on `debug`/`info`/`warning`/`error`/`critical` calls to receivers named `AppLoggerService`, `appLoggerService` or ending with `LoggerService`: map-literal `metadata:` keys equal to or ending with `token`, `password`, `authorization`, `cookie`, `secret`, `apikey`, `refreshtoken`, `accesstoken`, `passwd`, `credentials` or `bearer` (case-insensitive), and positional message literals/interpolations matching `password:`/`=`, `token:`, `Bearer <value>`, `api_key:`, `secret:` or `authorization:`.

## Why

Logs persist in plain text in observability systems; credentials in them are a security and privacy risk.

## Example

```dart
// BAD
AppLoggerService.warning('refresh failed', metadata: {'accessToken': token});
```

```dart
// GOOD
AppLoggerService.warning('refresh failed', metadata: {'tokenPresent': true});
```

## Disable if

Your project uses another logging API (then this rule has nothing to inspect).

## Options

None. Keys and patterns are fixed.

## Limits

- Literal keys and literal message text only; values in variables, nested maps and other logger APIs are not inspected.
- A literal-key check does not establish privacy; review redaction and sinks.

<!-- example-scope: isolated no_exception_message_passthrough -->

> **Example contract: `no_exception_message_passthrough` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_exception_message_passthrough

**Default severity**: info. Enabled by default.

## What it detects

Outside `/test/`, `/integration_test/` and `*_test.dart` files: (1) the right side of `??` when it is a raw payload; (2) named arguments `message`, `details`, `description`, `reason`, `error`, `cause`, `userMessage`, `displayMessage`, `body`, `subtitle` or `hint` carrying a raw payload, also inside interpolation; (3) the first positional argument of a `*Exception`/`*Failure` constructor carrying one. A raw payload is `.message`/`.toString()` on an error-like name, `error`/`detail(s)`/`reason`/`message`/`msg` on a response/model/result/payload/dto-like name, or a variable named like `errorMessage`/`backendMessage`/`rawMessage`.

## Why

Raw messages that travel through layers end up shown to users untranslated or leak internal details; stable codes should travel instead.

## Example

```dart
// BAD
final String userMessage = error.code ?? error.message;
```

```dart
// GOOD
final String errorCode = error.code ?? AppErrorCodes.unknown;
```

## Disable if

Your error model deliberately carries server-provided, localized text.

## Options

None.

## Limits

- Name-based heuristics: other names and indirect flows are not detected; legitimate technical messages with matching names are reported.
- Applies in all layers, including logging calls that use the listed argument names.

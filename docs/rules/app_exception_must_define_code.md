<!-- example-scope: isolated app_exception_must_define_code -->

> **Example contract: `app_exception_must_define_code` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# app_exception_must_define_code

**Default severity**: info. Enabled by default.

**WorkTracker-specific**: fixed `AppException` base with stable i18n code constants. Disable outside WorkTracker.

## What it detects

Two checks, outside `/test/`, `/integration_test/` and `*_test.dart` files: (1) concrete public classes that directly extend `AppException` without a `code` field, `code` getter, constructor parameter named `code` or `super(code: ...)` call; (2) a `code:` argument given as a string literal or interpolation when creating an `AppException` subtype, or any type whose name ends with `Exception` or `Failure`.

## Why

The presentation layer localizes errors by stable code. Classes without a code, or ad-hoc literal codes, cannot be translated reliably.

## Example

```dart
// BAD
class NotFoundAppException extends AppException {
  NotFoundAppException() : super(code: 'not_found');
}
```

```dart
// GOOD
class NotFoundAppException extends AppException {
  NotFoundAppException() : super(code: AppErrorCodes.notFound);
}
```

## Disable if

In any project outside WorkTracker that does not adopt the same convention. Your error model does not use an `AppException` base with stable codes.

## Options

None.

## Limits

- Only direct subclasses of a class named `AppException` are checked for a code.
- The literal check also applies to any `*Exception`/`*Failure` constructor with a `code:` argument, related or not.
- It does not verify that a code constant has a translation.

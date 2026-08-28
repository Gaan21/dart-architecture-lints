# `avoid_unawaited_ignore_without_reason`

Requires a `// ignore-reason: <explanation>` comment whenever one of the
unawaited-governance rules is suppressed via `// ignore:`.

Suppressing a lint with `// ignore:` without a reason makes it impossible to
audit whether the suppression was intentional or accidental. This rule forces
the developer to document why the async concern is safe to ignore.

## Covered rules

This rule activates when any of the following are suppressed:

- `avoid_unawaited`
- `avoid_async_in_provider_create`
- `avoid_async_wrapper_hides_unawaited`

## What it reports

Reports any `// ignore: <covered-rule>` comment that does **not** have a
`// ignore-reason: <non-empty text>` on the same line or the immediately
preceding line.

Message:

> `// ignore: <regla-unawaited>` sin justificación. Si necesitas suprimir la regla, añade `// ignore-reason: <motivo>` en la misma línea o la línea anterior explicando por qué es seguro ignorar el aviso.

## Examples

```dart
// ❌ BAD — no reason provided
// ignore: avoid_unawaited
fireAndForget();

// ✅ GOOD — reason on the preceding line
// ignore-reason: notificación fire-and-forget, fallo es no-crítico
// ignore: avoid_unawaited
analytics.track(event);

// ✅ GOOD — reason on the same line
// ignore: avoid_unawaited  ignore-reason: legacy call, migrar en Q3
legacyService.doThing();
```

## Notes

- Applies to the entire project (no path filtering).
- Generated files are automatically skipped.
- The `ignore-reason:` text must be non-empty — a bare `// ignore-reason:` is
  not accepted.
- Only the three unawaited rules above are monitored; other `// ignore:`
  suppressions are not affected.

<!-- example-scope: isolated avoid_async_wrapper_hides_unawaited -->

> **Example contract: `avoid_async_wrapper_hides_unawaited` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# avoid_async_wrapper_hides_unawaited

**Rule name**: `avoid_async_wrapper_hides_unawaited`
**Type**: Warning

---

## Overview

Detecta el anti-patrón de envolver un único `await` en un callback `async`
de `scheduleMicrotask`, `Timer.run` o `Future(...)` para evadir el warning
de Dart sobre Futures no esperados y, de paso, esquivar la regla `avoid_unawaited`.

Este patrón:
1. **Oculta** que hay un fire-and-forget — el code reviewer no lo ve como tal
2. **Evita** la gobernanza de `avoid_unawaited` (sin categoría ni motivo)
3. **Añade overhead** innecesario (microtask queue / Timer / Future extra)

## Criterio de detección (preciso para minimizar falsos positivos)

Solo se reporta cuando el callback async tiene **exactamente 1 statement**
que es `await <expr>;` o `return await <expr>;`.

Callbacks async con múltiples statements son orquestación legítima y **no
se reportan**.

## BAD — dispara la regla

```dart
// BAD - scheduleMicrotask con single await
scheduleMicrotask(() async {
  await doWork();
});

// BAD - Timer.run con single await
Timer.run(() async {
  await sendTelemetry();
});

// BAD - Future constructor con single await
Future(() async {
  await repo.prefetch();
});

// BAD - return await también se detecta
scheduleMicrotask(() async {
  return await doWork();
});
```

## GOOD — no dispara la regla

```dart
// GOOD - múltiples statements (orquestación legítima)
scheduleMicrotask(() async {
  await doStepA();
  await doStepB(); // 2 statements → no se reporta
});

// GOOD - usar unawaited directamente (con justificación)
// unawaited-ok: prefetch-noncritical - precarga de datos para siguiente pantalla
unawaited(repo.prefetch());

// GOOD - await correcto en método async
Future<void> _loadData() async {
  await repo.prefetch();
}

// GOOD - scheduleMicrotask con lógica real (no solo un await)
scheduleMicrotask(() async {
  final data = await repo.fetch();
  state = state.copyWith(data: data); // 2 statements
});
```

## Cómo corregir

### Opción 1 — `unawaited` explícito (preferida)

```dart
// ANTES:
scheduleMicrotask(() async { await doWork(); });

// DESPUÉS:
// unawaited-ok: best-effort-cleanup - limpieza en background NO-THROW
unawaited(doWork());
```

### Opción 2 — `await` correcto

```dart
// ANTES:
Timer.run(() async { await sendReport(); });

// DESPUÉS: delegar al ViewModel o método async
Future<void> _sendReport() async {
  await reportService.send();
}
```

### Opción 3 — Post-frame en Provider.create

```dart
// ANTES:
create: (ctx) {
  scheduleMicrotask(() async { await vm.init(); });
  return vm;
}

// DESPUÉS:
create: (ctx) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // unawaited-ok: post-frame-init - inicialización tras primer frame
    unawaited(vm.init());
  });
  return vm;
}
```

## How to Test This Rule

### Test File: `lib/test_async_wrapper.dart`

```dart
import 'dart:async';

Future<void> doWork() async {}
Future<void> doStepA() async {}
Future<void> doStepB() async {}

void testCases() {
  // SHOULD trigger (single await in scheduleMicrotask)
  scheduleMicrotask(() async {
    await doWork();
  });

  // SHOULD trigger (single await in Timer.run)
  Timer.run(() async {
    await doWork();
  });

  // SHOULD trigger (single await in Future constructor)
  Future(() async {
    await doWork();
  });

  // Should NOT trigger (2 statements)
  scheduleMicrotask(() async {
    await doStepA();
    await doStepB();
  });

  // Should NOT trigger (no await)
  scheduleMicrotask(() {
    doWork(); // no async, no await
  });
}
```

### Expected Results

```bash
$ dart run custom_lint

lib/test_async_wrapper.dart:9:3   - Anti-patrón: wrapper async con un solo `await`... - avoid_async_wrapper_hides_unawaited
lib/test_async_wrapper.dart:14:3  - Anti-patrón: wrapper async con un solo `await`... - avoid_async_wrapper_hides_unawaited
lib/test_async_wrapper.dart:19:3  - Anti-patrón: wrapper async con un solo `await`... - avoid_async_wrapper_hides_unawaited
```

## Related Guidelines

- `avoid_unawaited` — gobernanza de fire-and-forget (usa esto en su lugar)
- `avoid_async_in_provider_create` — patrón correcto en Provider.create

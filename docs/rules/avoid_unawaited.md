# avoid_unawaited

**Rule name**: `avoid_unawaited`
**Type**: Warning
**Secondary rules**: `avoid_unawaited_ignore_without_reason` (warning)

---

## Overview

Detecta cualquier uso de `unawaited(...)` (de `dart:async`) sin una justificación
estructurada. `unawaited` solo debe usarse en tareas *fire-and-forget* legítimas,
documentadas con la categoría y el motivo exacto.

## Formato de justificación (obligatorio desde v2)

```dart
// unawaited-ok: <categoría> - <motivo>
```

### Categorías válidas

| Categoría | Cuándo usarla |
|-----------|---------------|
| `dispose-sync` | Limpieza en `dispose()`, p.ej. cerrar StreamController |
| `callback-sync` | Dentro de Stream.listen / lifecycle callbacks síncronos |
| `telemetry/logging` | Analytics, logs, métricas — no críticos para el flujo |
| `best-effort-cleanup` | Limpieza de caché/recursos — error capturado internamente |
| `post-frame-init` | Inicialización tras primer frame, dentro de addPostFrameCallback |
| `prefetch-noncritical` | Precarga nice-to-have — la UI no depende del resultado |

**Regla adicional**: el método pasado a `unawaited` DEBE ser NO-THROW.
Captura excepciones internamente (try/catch + logging central) para que
los errores no se pierdan en el `Zone.onError`.

## Motivación

`unawaited(...)` silencia el warning de Dart sobre Futures no esperados.
Su mal uso esconde bugs críticos:

1. **Pérdida de errores**: Si el Future falla, el error se pierde silenciosamente
2. **Race conditions**: Operaciones que deberían ser secuenciales se ejecutan en paralelo
3. **Estado inconsistente**: La UI puede mostrar datos obsoletos
4. **Carreras de doble tap**: Un segundo tap puede duplicar la operación

## BAD — dispara la regla

```dart
// BAD - Sin justificación
unawaited(repo.save());

// BAD - Sin comentario unawaited-ok
unawaited(analytics.track('open'));

// BAD - Formato antiguo (sin categoría)
unawaited(repo.prefetch()); // unawaited-ok: precarga no crítica

// BAD - Categoría inválida
unawaited(cache.clear()); // unawaited-ok: background - limpieza
// ^^ 'background' no es una categoría válida

// BAD - Sin razón tras el separador
unawaited(logger.flush()); // unawaited-ok: telemetry/logging -

// BAD - En Provider.create (también dispara avoid_async_in_provider_create)
ChangeNotifierProvider(
  create: (ctx) {
    unawaited(vm.loadInitialData());  // ERROR
    return vm;
  },
)
```

## GOOD — no dispara la regla

```dart
// GOOD - Telemetría con categoría y motivo
unawaited(analytics.trackOpen()); // unawaited-ok: telemetry/logging - no bloquea UX

// GOOD - Comentario en línea anterior
// unawaited-ok: prefetch-noncritical - dashboard precarga para mejorar UX
unawaited(repo.prefetchDashboard());

// GOOD - Dispose sync
@override
void dispose() {
  // unawaited-ok: dispose-sync - cerrando StreamController al destruir el widget
  unawaited(_streamController.close());
  super.dispose();
}

// GOOD - Post-frame init dentro de addPostFrameCallback
ChangeNotifierProvider(
  create: (ctx) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // unawaited-ok: post-frame-init - carga inicial tras primer frame
      unawaited(vm.loadInitialData());
    });
    return vm;
  },
)

// GOOD - Usar await en su lugar (preferido)
await repo.save();

// GOOD - Fire-and-forget con captura explícita
unawaited(
  analytics.track('event').catchError((e) => logger.warn('Analytics failed: $e')),
); // unawaited-ok: telemetry/logging - fallo de analytics no crítico para el flujo
```

## Reglas relacionadas

### `avoid_async_in_provider_create`

Detecta `unawaited(...)` directamente dentro de `Provider.create` sin
`addPostFrameCallback`. Ver [avoid_async_in_provider_create.md](avoid_async_in_provider_create.md).

### `avoid_async_wrapper_hides_unawaited`

Detecta wrappers `scheduleMicrotask/Timer.run/Future` con un solo `await`
para evadir la gobernanza. Ver [avoid_async_wrapper_hides_unawaited.md](avoid_async_wrapper_hides_unawaited.md).

### `avoid_unawaited_ignore_without_reason`

Si alguien usa `// ignore: avoid_unawaited` (o las reglas nuevas) para
suprimir, debe acompañarlo con `// ignore-reason: <motivo>`.

```dart
// BAD
// ignore: avoid_unawaited
unawaited(legacy.doThing());

// GOOD
// ignore-reason: código legacy, pendiente de refactorizar en sprint 42
// ignore: avoid_unawaited
unawaited(legacy.doThing());
```

## How to Test This Rule

### Setup Test Project

1. Usar un proyecto Flutter con este custom lint como dependencia
2. Asegurarse de que el proyecto importa `dart:async`

### Test File: `lib/test_avoid_unawaited.dart`

```dart
import 'dart:async';

class FakeAnalytics {
  Future<void> trackOpen() async {}
}

class FakeRepo {
  Future<void> save() async {}
  Future<void> prefetchDashboard() async {}
}

void testCases() {
  final analytics = FakeAnalytics();
  final repo = FakeRepo();

  // SHOULD trigger avoid_unawaited (no comment)
  unawaited(repo.save());

  // SHOULD trigger avoid_unawaited (old format, no category)
  unawaited(repo.save()); // unawaited-ok: precarga no crítica

  // SHOULD trigger avoid_unawaited (invalid category)
  unawaited(repo.save()); // unawaited-ok: background - limpieza

  // SHOULD trigger avoid_unawaited (empty reason)
  unawaited(repo.save()); // unawaited-ok: dispose-sync -

  // Should NOT trigger - valid category + reason (same line)
  unawaited(analytics.trackOpen()); // unawaited-ok: telemetry/logging - no bloquea UX

  // Should NOT trigger - valid category + reason (previous line)
  // unawaited-ok: prefetch-noncritical - dashboard precarga para mejorar UX
  unawaited(repo.prefetchDashboard());
}
```

### Expected Results

```bash
$ dart run custom_lint

lib/test_avoid_unawaited.dart:17:3  - Uso de `unawaited(...)` sin justificación... - avoid_unawaited
lib/test_avoid_unawaited.dart:20:3  - Categoría en `// unawaited-ok:` inválida... - avoid_unawaited
lib/test_avoid_unawaited.dart:23:3  - Categoría en `// unawaited-ok:` inválida... - avoid_unawaited
lib/test_avoid_unawaited.dart:26:3  - Categoría en `// unawaited-ok:` inválida... - avoid_unawaited
```

## Alternativas recomendadas

### 1. Convertir a `async` + `await` (preferido)

```dart
Future<void> saveData() async {
  final result = await repo.save();
  // manejar resultado
}
```

### 2. Gestionar estado en el ViewModel

```dart
class MyViewModel extends BaseViewModel<MyState> {
  Future<void> loadData() async {
    state = state.copyWith(status: Status.loading);
    final result = await useCase.execute(params);
    result.when(
      success: (data) => state = state.copyWith(status: Status.success, data: data),
      failure: (error) => state = state.copyWith(status: Status.error, error: error),
    );
  }
}
```

### 3. Fire-and-forget seguro (NO-THROW + logging central)

```dart
Future<void> _sendTelemetry(String event) async {
  try {
    await analytics.track(event);
  } catch (e, st) {
    // Un solo log — no duplicar en capas UI
    ErrorReporterRegistry.instance.report(e, st);
  }
}

// unawaited-ok: telemetry/logging - método NO-THROW, error capturado internamente
unawaited(_sendTelemetry('screen_view'));
```

## Related Guidelines

- Result Pattern: operaciones críticas deben usar `Result<T>` y ser `await`-eadas

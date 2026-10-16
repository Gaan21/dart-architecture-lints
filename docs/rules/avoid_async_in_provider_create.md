<!-- example-scope: isolated avoid_async_in_provider_create -->

> **Example contract: `avoid_async_in_provider_create` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# avoid_async_in_provider_create

**Rule name**: `avoid_async_in_provider_create`
**Type**: Warning
**Complemented by**: `avoid_unawaited` (still fires for the missing comment)

---

## Overview

Detecta `unawaited(...)` ejecutado directamente dentro del closure `create`
(o `update`) de un `Provider` sin estar envuelto en `addPostFrameCallback`.

Operaciones asíncronas en `Provider.create` se ejecutan **durante la fase
de build** del árbol de widgets. Mutar estado en ese momento provoca:

- `setState() or markNeedsBuild() called during build` — crash en debug
- Race conditions entre la construcción del widget y la mutación del estado
- Errores difíciles de reproducir en producción

## Regla de excepción

Si `unawaited(...)` está dentro de un callback de `addPostFrameCallback`,
**no** se reporta: las mutaciones ocurren después del primer frame, lo cual
es el patrón seguro.

## Detection heuristic

Se detecta cuando:
1. `unawaited(...)` está dentro de un `NamedExpression` con nombre `create` o `update`
2. Dicho `NamedExpression` pertenece a un `InstanceCreationExpression` cuyo
   tipo contiene la cadena `"Provider"` (p.ej. `ChangeNotifierProvider`,
   `Provider`, `ProxyProvider`, `FutureProvider`, etc.)
3. NO hay ningún ancestro `addPostFrameCallback` entre el `unawaited` y el `create`

**Limitación conocida**: wrappers propios que no incluyan "Provider" en el
nombre de clase no son detectados por este heurístico.

## BAD — dispara la regla

```dart
// BAD - async directo en create
ChangeNotifierProvider(
  create: (ctx) {
    unawaited(vm.loadInitialData()); // avoid_async_in_provider_create + avoid_unawaited
    return vm;
  },
)

// BAD - aunque tenga comentario unawaited-ok, sigue en build-time
ChangeNotifierProvider(
  create: (ctx) {
    // unawaited-ok: post-frame-init - carga inicial
    unawaited(vm.loadInitialData()); // avoid_async_in_provider_create aún dispara
    return vm;
  },
)
```

## GOOD — no dispara la regla

```dart
// GOOD - post-frame callback + unawaited con comentario
ChangeNotifierProvider(
  create: (ctx) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // unawaited-ok: post-frame-init - carga inicial tras primer frame
      unawaited(vm.loadInitialData());
    });
    return vm;
  },
)

// GOOD - sin unawaited: el VM carga en su propio initState / el screen hace await
ChangeNotifierProvider(
  create: (ctx) => MyViewModel(),
)
```

## Cómo corregir paso a paso

### Paso 1 — Mover a post-frame

```dart
// ANTES (dispara ambas reglas):
create: (ctx) {
  unawaited(vm.init());
  return vm;
}

// DESPUÉS (solo dispara avoid_unawaited si falta el comentario):
create: (ctx) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(vm.init());
  });
  return vm;
}
```

### Paso 2 — Añadir comentario estructurado

```dart
create: (ctx) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // unawaited-ok: post-frame-init - carga inicial de datos tras construcción
    unawaited(vm.init());
  });
  return vm;
}
```

## How to Test This Rule

### Test File: `lib/test_async_in_provider_create.dart`

```dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class MyVm {
  Future<void> init() async {}
}

Widget bad() {
  return ChangeNotifierProvider(
    // SHOULD trigger avoid_async_in_provider_create
    create: (ctx) {
      unawaited(MyVm().init());
      return MyVm();
    },
    child: const SizedBox(),
  );
}

Widget good() {
  return ChangeNotifierProvider(
    // Should NOT trigger (inside addPostFrameCallback)
    create: (ctx) {
      final vm = MyVm();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // unawaited-ok: post-frame-init - inicialización segura post-build
        unawaited(vm.init());
      });
      return vm;
    },
    child: const SizedBox(),
  );
}
```

### Expected Results

```bash
$ dart run custom_lint

lib/test_async_in_provider_create.dart:15:7  - Async en build-time prohibido... - avoid_async_in_provider_create
lib/test_async_in_provider_create.dart:15:7  - Uso de `unawaited(...)` sin justificación... - avoid_unawaited
```

## Related Guidelines

- `avoid_unawaited` — regla base de gobernanza de fire-and-forget

# logger_context_matches_scope

**Rule name**: `logger_context_matches_scope`  
**Severity**: Warning

## Propósito

Hace que el `context` de logs en `AppLoggerService.error(...)` y `AppLoggerService.warning(...)` sea resistente a renames, validando que coincida con el scope real del símbolo envolvente.

## Alcance v1 (pragmático)

La regla solo aplica cuando se cumple todo:

- Archivo dentro de `work_tracker/lib/**`
- Llamada a `AppLoggerService.error(...)` o `AppLoggerService.warning(...)`
- Existe named arg `context`
- `context` es string literal simple
- La llamada está dentro de miembro de `class`/`mixin`/`enum`/`extension`

Si no se puede inferir scope fiable, la regla **no reporta** (evita falsos positivos).

## Derivación de expected context

Formato esperado: `typeName.memberCanonical`

`memberCanonical`:
- elimina prefijo `_` si existe
- elimina sufijo `Internal` si existe
- mantiene el resto intacto

Ejemplos:
- `_loadEstadoInternal` -> `ClockViewModel.loadEstado`
- `_runEffectFuture` -> `UiEffectsHandler.runEffectFuture`
- `fromBackendValue` -> `EstadoJornadaEnum.fromBackendValue`

## Diagnóstico

Cuando falla, el lint muestra explícitamente:
- `expected: "<valor esperado>"`
- `actual: "<valor actual>"`

## Ejemplos

### ✅ Pasa

```dart
class ClockViewModel {
  void _loadEstadoInternal() {
    AppLoggerService.warning(
      'x',
      context: 'ClockViewModel.loadEstado',
    );
  }
}
```

```dart
class A {
  void load() {
    AppLoggerService.error('x', context: 'A.load');
  }
}
```

### ❌ Falla

```dart
class ClockViewModel {
  void _loadEstadoInternal() {
    AppLoggerService.warning(
      'x',
      context: 'ClockViewModel.loadEstadoInternal',
    );
  }
}
```

## Limitaciones v1

- No valida `info()` ni `debug()`.
- No valida `context` que no sea string literal simple.
- No reporta en funciones top-level.
- Constructores sin nombre se omiten en v1 para evitar contextos ambiguos.

## Guideline relacionada


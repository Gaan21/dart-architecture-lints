# no_direct_error_logging_in_data_domain

**Rule name**: `no_direct_error_logging_in_data_domain`
**Severity**: Error

## Propósito

Previene llamadas directas a `AppLoggerService.error()` y `AppLoggerService.warning()` en las capas `data/` y `domain/`. En Clean Architecture con Guard pattern, los errores se reportan de forma centralizada en `GuardMixin`/`BaseUseCase` vía `ErrorReporter`. Loguear errores directamente en data/domain causa **doble-logging** y ruido en observabilidad.

## Diagnóstico

La regla se activa cuando:
- Un archivo en `lib/data/**` o `lib/domain/**` contiene una llamada a `AppLoggerService.error(...)` o `AppLoggerService.warning(...)`
- El archivo **no** está en la allowlist de excepciones técnicas

**Por qué aparece**: El error ya se centraliza en Guard/ErrorReporter. Una llamada directa duplica el evento en los sistemas de observabilidad, incrementa coste y dificulta el filtrado de señales reales.

## Soluciones

### Rápida: Eliminar la llamada y devolver Failure
```dart
// ❌ MAL - Logging directo en Repository
class UserRepositoryImpl extends BaseRepository implements UserRepository {
  Future<Result<User>> getUser(int id) async {
    try {
      final model = await dataSource.fetchUser(id);
      return Result.success(mapper.toEntity(model));
    } catch (e, st) {
      AppLoggerService.error('Failed to fetch user', error: e, stackTrace: st); // ← VIOLA
      return Result.failure(AppException.unexpected(e));
    }
  }
}
```

```dart
// ✅ BIEN - Delegar logging al Guard/ErrorReporter
class UserRepositoryImpl extends BaseRepository implements UserRepository {
  Future<Result<User>> getUser(int id) async {
    return guard(() async {
      final model = await dataSource.fetchUser(id);
      return mapper.toEntity(model);
    });
  }
}
```

### Recomendada: Usar guard() que ya loguea internamente
El patrón `guard()` de `BaseRepository` captura excepciones, las mapea a `AppException`, y las reporta vía `ErrorReporter` automáticamente. No necesitas loguear manualmente.

### Alternativa: Si realmente necesitas logging local
Si hay un caso técnico que justifica logging local (ej: fallback silencioso que no es error), documenta la razón y solicita añadir el archivo al allowlist.

## Ejemplos

### ❌ MAL (dispara la regla)
```dart
// En lib/data/repositories/order_repository_impl.dart
AppLoggerService.error('Order fetch failed', error: e);
AppLoggerService.warning('Slow query detected', context: 'OrderRepo.fetchAll');
```

### ✅ BIEN (no dispara la regla)
```dart
// En lib/data/repositories/order_repository_impl.dart
// Usa guard() que loguea internamente
return guard(() async {
  final orders = await dataSource.fetchOrders();
  return orders.map(mapper.toEntity).toList();
});

// Info/debug SÍ están permitidos (solo error/warning están prohibidos)
AppLoggerService.info('Cache miss for orders', context: 'OrderRepo.fetchAll');
```

### ✅ BIEN (archivos en allowlist)
```dart
// En lib/core/mixins/guard_mixin.dart - PERMITIDO
AppLoggerService.error('Unhandled exception in guard', error: e);

// En lib/core/services/error_reporter_service.dart - PERMITIDO
AppLoggerService.error('Critical error reported', error: e);
```

## Falsos positivos conocidos

| Caso | Probabilidad | Mitigación |
|------|-------------|------------|
| Logger con nombre diferente a AppLoggerService | Baja | La regla detecta por nombre de clase, no por tipo exacto |
| Archivos en data/domain que legítimamente necesitan warning | Baja | Solicitar añadir al allowlist con justificación |
| Variables tipadas como AppLoggerService | Baja | Se verifica tipo estático del target |

**Tasa estimada de falsos positivos**: < 5%

## Política de excepciones

**Allowlist actual**:
- `lib/core/mixins/guard_mixin.dart`
- `lib/domain/useCases/base_use_case.dart`
- `lib/core/services/error_reporter_service.dart`
- `lib/core/services/app_logger_service.dart`

Para añadir un archivo al allowlist:
1. Documenta la justificación técnica
2. Solicita aprobación del usuario
3. Añade la ruta al array `_allowlistSuffixes` en la regla

## Checklist de migración (código legacy)

- [ ] Buscar `AppLoggerService.error` y `AppLoggerService.warning` en `lib/data/` y `lib/domain/`
- [ ] Para cada ocurrencia, verificar si el guard ya cubre el caso
- [ ] Si sí: eliminar la llamada directa
- [ ] Si no: refactorizar para usar `guard()` o `Result.failure()`
- [ ] Si es caso excepcional: documentar y añadir al allowlist
- [ ] Ejecutar `dart run custom_lint` para verificar 0 violaciones

## Guideline relacionada


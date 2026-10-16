<!-- example-scope: isolated logger_context_must_be_structured -->

> **Example contract: `logger_context_must_be_structured` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# logger_context_must_be_structured

**Rule name**: `logger_context_must_be_structured`
**Severity**: Warning

## Propósito

Asegura que todas las llamadas a `AppLoggerService` incluyan un parámetro `context` con formato estructurado y determinista. Un context inconsistente rompe la trazabilidad, impide agrupar logs por origen, y dificulta el diagnóstico en producción.

## Diagnóstico

La regla se activa cuando una llamada a `AppLoggerService.{debug|info|warning|error|critical}()`:
1. **No tiene parámetro `context`** en absoluto
2. **Context vacío**: `context: ""`
3. **Context genérico**: `context: "test"`, `"debug"`, `"tmp"`, `"temp"`, etc.
4. **Context sin formato dot-notation**: no sigue `Class.method` ni `module.submodule.action`

**Por qué aparece**: Sin un context estructurado, los logs no se pueden filtrar ni agrupar en dashboards (ELK, CloudWatch, Datadog). Un context como `"test"` o vacío es indistinguible de miles de otros logs.

## Soluciones

### Rápida: Añadir context con Class.method
```dart
// ❌ MAL
AppLoggerService.info('User loaded');

// ✅ BIEN
AppLoggerService.info('User loaded', context: 'UserRepository.fetchById');
```

### Recomendada: Usar formato consistente
```dart
// Formato Class.method (preferido para código en clases)
AppLoggerService.info('Cache hit', context: 'OrderCache.get');

// Formato module.submodule.action (preferido para flujos cross-cutting)
AppLoggerService.info('Sync started', context: 'sync.pull.start');
AppLoggerService.warning('Conflict detected', context: 'sync.merge.conflict');
```

### Alternativa: Variables o constantes
```dart
// La regla solo valida literales de string.
// Variables son aceptadas (no se pueden validar estáticamente).
static const _ctx = 'UserViewModel.loadData';
AppLoggerService.info('Loading...', context: _ctx);
```

## Ejemplos

### ❌ MAL (dispara la regla)
```dart
// Sin context
AppLoggerService.info('Order created');

// Context vacío
AppLoggerService.error('Failed', context: '');

// Context genérico
AppLoggerService.debug('testing', context: 'test');
AppLoggerService.info('checking', context: 'debug');
AppLoggerService.warning('temporal', context: 'tmp');

// Context sin dot-notation
AppLoggerService.info('loaded', context: 'user loaded');
AppLoggerService.info('ok', context: 'myFunction');
```

### ✅ BIEN (no dispara la regla)
```dart
// Formato Class.method
AppLoggerService.info('User loaded', context: 'UserRepository.fetchById');
AppLoggerService.error('Parse failed', context: 'OrderMapper.toEntity');

// Formato module.submodule.action
AppLoggerService.info('Sync complete', context: 'sync.push.complete');
AppLoggerService.debug('Cache warm', context: 'cache.orders.warmUp');

// Variable (no se valida estáticamente)
final ctx = '${runtimeType}.fetchData';
AppLoggerService.info('Fetching...', context: ctx);
```

## Falsos positivos conocidos

| Caso | Probabilidad | Mitigación |
|------|-------------|------------|
| Context dinámico válido pasado como variable | N/A | La regla no valida variables, solo literales de string |
| Logging en archivos fuera de lib/ | N/A | La regla solo aplica a `lib/` |
| Servicios de logging con API diferente a AppLoggerService | Baja | No se detectan (solo AppLoggerService) |

**Tasa estimada de falsos positivos**: < 10%

## Política de excepciones

No hay excepciones formales para esta regla. Si un caso legítimo necesita context dinámico:
- Usar una variable/constante en vez de literal de string
- La regla solo valida literales; variables pasan automáticamente

## Checklist de migración (código legacy)

- [ ] Buscar llamadas a `AppLoggerService` sin parámetro `context`
- [ ] Para cada llamada, determinar el contexto correcto (clase + método actual)
- [ ] Reemplazar contextos genéricos ("test", "debug", etc.) por contextos estructurados
- [ ] Normalizar contextos existentes al formato `Class.method`
- [ ] Ejecutar `dart run custom_lint` para verificar 0 violaciones

## Formatos válidos de context

| Formato | Ejemplo | Uso recomendado |
|---------|---------|-----------------|
| `Class.method` | `"UserRepo.fetchAll"` | Código dentro de clases |
| `module.action` | `"sync.start"` | Flujos transversales |
| `module.submodule.action` | `"auth.token.refresh"` | Flujos con múltiples pasos |

## Guideline relacionada

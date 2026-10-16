<!-- example-scope: isolated no_exception_message_passthrough -->

> **Example contract: `no_exception_message_passthrough` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_exception_message_passthrough

**Severidad**: `warning`
**Capa**: todas (domain, data, presentation)

## Objetivo

Detectar patrones donde mensajes crudos de excepción se reenvían entre capas hacia la UI, incluso cuando aún no están en un componente UI directamente.

Este patrón es más sutil que `no_raw_exception_message_to_user` y ocurre cuando:
- Se crea un fallback `error.code ?? error.message` (el mensaje crudo como último recurso)
- Se pasa `error.message` como argumento con nombre a funciones que eventualmente lo muestran al usuario

## Detección

### Patrón 1: Fallback `?? error.message`

Expresión binaria `??` donde el lado derecho accede a `.message` de una variable de excepción:

```dart
error.code ?? error.message  // ← warning en el lado derecho
```

### Patrón 2: Named args con mensajes crudos

Argumentos con nombre que sugieren contenido visible al usuario (`message`, `details`, `description`, `reason`, `error`, `cause`, `userMessage`, `displayMessage`, `body`, `subtitle`, `hint`) cuyo valor es un mensaje crudo de excepción:

```dart
AppException(details: innerError.message)        // ← warning
SomeResult(reason: exception.toString())          // ← warning
throw MyException(description: e.message)         // ← warning
```

### Patrón 3: Interpolaciones en args de mensaje

String interpolaciones dentro de los args anteriores:

```dart
throw AppException(details: 'Error: ${error.message}')  // ← warning
```

**Variables consideradas como excepción**: `error`, `err`, `e`, `exception`, `ex`, `failure`, o cualquier variable cuyo nombre termine en `Exception`, `Error`, `Failure`, `AppException`.

## Ejemplos

### ❌ MAL — fallback a mensaje crudo

```dart
// data/repositories/user_repository_impl.dart
Future<Result<User>> getUser(String id) async {
  try {
    return Result.ok(await _datasource.fetchUser(id));
  } on AppException catch (error) {
    // MAL: error.message como fallback — mensaje crudo llega al caller
    final code = error.code ?? error.message;  // ← warning
    return Result.error(AppException(code: code));
  }
}
```

### ❌ MAL — passthrough en constructor de excepción

```dart
// domain/usecases/sync_usecase.dart
Future<Result<void>> execute(NoParams _) async {
  final result = await _repo.sync();
  return result.mapError((e) {
    // MAL: reenvía mensaje crudo en campo 'details'
    return NetworkException(details: e.message);  // ← warning
  });
}
```

### ✅ BIEN — código estable como fallback

```dart
Future<Result<User>> getUser(String id) async {
  try {
    return Result.ok(await _datasource.fetchUser(id));
  } on AppException catch (error) {
    final code = error.code ?? AppErrorCodes.unknown;  // ← sin warning
    return Result.error(AppException(code: code));
  }
}
```

### ✅ BIEN — propaga código, no mensaje

```dart
return result.mapError((e) {
  // Propaga el código estable, no el mensaje crudo
  return NetworkException(code: e.code ?? AppErrorCodes.network);
});
```

## Diferencia con `no_raw_exception_message_to_user`

| Regla | Dónde detecta | Qué detecta |
|-------|--------------|-------------|
| `no_raw_exception_message_to_user` | Solo `presentation/` | Uso en widgets UI directamente |
| `no_exception_message_passthrough` | Todas las capas | Patrones de reenvío entre capas |

Ambas reglas son complementarias: la primera captura el acceso directo en UI, la segunda captura el reenvío intermedio.

## Testing guide

### Setup en proyecto consumidor

```dart
// lib/data/repositories/test_repo.dart
class TestRepository {
  Future<Result<String>> fetch() async {
    try {
      return Result.ok('data');
    } on AppException catch (e) {
      // ❌ Debe reportar warning:
      final code = e.code ?? e.message;
      return Result.error(AppException(code: code));
    }
  }
}

class TestUseCase {
  void handle(AppException error) {
    // ❌ Debe reportar warning:
    throw AnotherException(details: error.message);

    // ✅ No debe reportar:
    throw AnotherException(code: error.code ?? AppErrorCodes.unknown);
  }
}
```

Ejecutar:

```bash
dart run custom_lint
```

### Verificar

- [ ] `e.code ?? e.message` → warning en `e.message`
- [ ] `details: error.message` (named arg) → warning
- [ ] `reason: exception.toString()` (named arg) → warning
- [ ] `details: 'Error: ${error.message}'` (interpolación) → warning
- [ ] `code: e.code ?? AppErrorCodes.unknown` → sin warning
- [ ] `final x = e.message` (sin named arg y sin `??`) → sin warning (fuera del scope de esta regla)

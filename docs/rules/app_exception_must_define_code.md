<!-- example-scope: isolated app_exception_must_define_code -->

> **Example contract: `app_exception_must_define_code` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# app_exception_must_define_code

**Severidad**: `warning`
**Capa**: todas (cualquier archivo con subtipos de `AppException`)

## Objetivo

Forzar que todas las excepciones de aplicación que puedan llegar a la UI definan un `code` estable, que la capa de presentación usa para obtener el mensaje localizado.

Sin `code`, la presentación no puede distinguir tipos de error ni localizarlos, y acaba mostrando mensajes crudos o genéricos.

## Detección

Analiza clases que:
- Extienden directamente `AppException`
- No son abstractas
- No son privadas

Y verifica que el `code` esté definido mediante **alguno** de estos mecanismos:

| Mecanismo | Ejemplo |
|-----------|---------|
| Campo de instancia | `final String code = 'not_found';` |
| Override de getter | `@override String get code => AppErrorCodes.notFound;` |
| Parámetro de constructor | `MyException({required String code})` |
| Super constructor con named arg | `super(code: 'network_error')` |
| Campo formal `this.code` | `MyException(this.code)` |

## Ejemplos

### ❌ MAL — sin code

```dart
class UserNotFoundException extends AppException {
  UserNotFoundException({required super.message});
  // ← warning: no tiene 'code'
}
```

### ❌ MAL — solo mensaje, sin code

```dart
class NetworkException extends AppException {
  final int statusCode;
  NetworkException({required this.statusCode, required super.message});
  // ← warning: statusCode no es code
}
```

### ✅ BIEN — code en super constructor

```dart
class UserNotFoundException extends AppException {
  UserNotFoundException({required super.message})
    : super(code: AppErrorCodes.userNotFound);  // ← sin warning
}
```

### ✅ BIEN — code como campo

```dart
class NetworkException extends AppException {
  @override
  final String code = AppErrorCodes.network;  // ← sin warning

  NetworkException({required super.message, required this.statusCode});
  final int statusCode;
}
```

### ✅ BIEN — code como getter

```dart
class TimeoutException extends AppException {
  @override
  String get code => AppErrorCodes.timeout;  // ← sin warning

  TimeoutException() : super(message: 'Request timed out');
}
```

### ✅ BIEN — clase abstracta (no se verifica)

```dart
// Las clases abstractas pueden omitir code (definen la interfaz)
abstract class BaseNetworkException extends AppException {
  const BaseNetworkException({required super.message, required super.code});
}
```

## Nota sobre excepciones internas

Si una excepción es estrictamente interna (nunca llega a la UI), puede anotar la clase con un comentario explicativo. Sin embargo, la regla no diferencia entre excepciones internas y externas en la implementación actual — si extiendes `AppException`, debes definir `code`.

Si una excepción es verdaderamente interna, considera:
- Extender `Exception` directamente en lugar de `AppException`
- O definir un código interno (ej: `AppErrorCodes.internal`)

## Testing guide

### Setup en proyecto consumidor

```dart
// lib/core/exceptions/test_exceptions.dart

// ❌ Debe reportar warning:
class NoCodeException extends AppException {
  NoCodeException() : super(message: 'Something went wrong');
}

// ✅ No debe reportar:
class WithCodeException extends AppException {
  WithCodeException() : super(code: 'test_error', message: 'Test error');
}

// ✅ No debe reportar (abstracta):
abstract class BaseTestException extends AppException {
  const BaseTestException({required super.code, required super.message});
}
```

Ejecutar:

```bash
dart run custom_lint
```

### Verificar

- [ ] `extends AppException` sin `code` en ningún mecanismo → warning
- [ ] `super(code: 'xxx')` → sin warning
- [ ] `final String code = 'xxx'` → sin warning
- [ ] `String get code => 'xxx'` → sin warning
- [ ] Clase abstracta → sin warning
- [ ] Clase privada `_MyException` → sin warning

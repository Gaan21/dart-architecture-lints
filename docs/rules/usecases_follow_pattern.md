# usecases_follow_pattern

**Nivel**: MEDIO | **Tipo**: Architectural | **Área**: Clean Architecture

## Descripción

Esta regla enforza el patrón estándar para clases UseCase en Clean Architecture. Verifica que todas las clases que terminan en "UseCase" implementen un método público `execute()` que retorne `Result<T>` o `Future<Result<T>>`, garantizando consistencia en contratos de casos de uso.

## ¿Por qué es importante?

- **Clean Architecture**: Mantiene el patrón estándar de casos de uso
- **Error handling**: Garantiza manejo consistente de errores sin excepciones
- **Contract consistency**: Todos los UseCases tienen la misma interfaz
- **Testability**: Facilita testing y mocking de casos de uso
- **Team alignment**: Evita variaciones en implementación de UseCases

## Ejemplos

### ✅ Código correcto (no debe alertar)

```dart
// UseCase con patrón correcto
class GetUserUseCase extends BaseUseCase<User, String> {
  final UserRepository repository;
  
  GetUserUseCase(this.repository);
  
  @override
  Future<Result<User>> execute(String userId) async {
    try {
      final user = await repository.findById(userId);
      return Result.success(user);
    } catch (e) {
      return Result.failure(UserNotFoundError());
    }
  }
}

// UseCase sin herencia pero con patrón correcto
class CreateUserUseCase {
  final UserRepository repository;
  final ValidationService validator;
  
  CreateUserUseCase(this.repository, this.validator);
  
  Future<Result<User>> execute(CreateUserParams params) async {
    final validationResult = validator.validate(params);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error);
    }
    
    final user = await repository.create(params);
    return Result.success(user);
  }
  
  // ✅ Métodos privados permitidos
  String _normalizeEmail(String email) => email.toLowerCase().trim();
}

// UseCase síncrono también válido
class ValidateEmailUseCase {
  Result<bool> execute(String email) {
    if (email.contains('@')) {
      return Result.success(true);
    }
    return Result.failure(InvalidEmailError());
  }
}

// Abstract UseCase - no requiere implementación
abstract class BaseUseCase<T, P> {
  Future<Result<T>> execute(P params);
}
```

### ❌ Código incorrecto (debe alertar)

```dart
// ❌ Falta método execute()
class GetUserUseCase {
  final UserRepository repository;
  
  GetUserUseCase(this.repository);
  
  Future<Result<User>> getData(String userId) async { // ❌ Método incorrecto
    return repository.findById(userId);
  }
  
  Future<Result<User>> fetchUser(String id) async { // ❌ Nombre incorrecto
    return repository.findById(id);
  }
}

// ❌ execute() existe pero return type incorrecto
class DeleteUserUseCase {
  final UserRepository repository;
  
  DeleteUserUseCase(this.repository);
  
  Future<void> execute(String userId) async { // ❌ Debe retornar Result<void>
    await repository.delete(userId);
  }
}

// ❌ execute() retorna tipo directo en lugar de Result<T>
class UpdateUserUseCase {
  final UserRepository repository;
  
  UpdateUserUseCase(this.repository);
  
  Future<User> execute(UpdateUserParams params) async { // ❌ Debe ser Future<Result<User>>
    return await repository.update(params);
  }
  
  User executeSync(UpdateUserParams params) { // ❌ Debe ser Result<User>
    return repository.updateSync(params);
  }
}

// ❌ execute() privado
class ProcessDataUseCase {
  Future<Result<Data>> _execute(ProcessParams params) async { // ❌ Debe ser público
    // Implementation
  }
  
  Future<Result<Data>> process(ProcessParams params) async {
    return _execute(params);
  }
}
```

## Patrón enforçado

### Estructura requerida para UseCases:

```dart
class [Name]UseCase {
  // Dependencies (repositories, services, etc.)
  final Repository repository;
  
  // Constructor
  [Name]UseCase(this.repository);
  
  // ✅ REQUERIDO: Método público execute()
  Future<Result<T>> execute(Params params) async {
    // Implementation that returns Result<T>
  }
  
  // ✅ OPCIONAL: Métodos privados/protected
  String _privateMethod() { }
  
  @protected
  void protectedMethod() { }
}
```

### Return types válidos:

1. **Result<T>** - Para operaciones síncronas
2. **Future<Result<T>>** - Para operaciones asíncronas

### Return types inválidos:

❌ `void` / `Future<void>`
❌ `T` / `Future<T>` (tipo directo)
❌ `bool` / `Future<bool>`
❌ `Either<Error, T>` (otros monads)
❌ Cualquier tipo que no sea `Result<T>`

## Testing guide

### Setup de testing

```bash
dart create test_usecase_patterns
cd test_usecase_patterns
```

### Configuración

En `analysis_options.yaml`:
```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    - usecases_follow_pattern
```

### Casos de prueba

Crea `lib/test_invalid_usecases.dart`:

```dart
// ESTE ARCHIVO DEBE GENERAR 5 WARNINGS

// ❌ WARNING 1: Sin método execute()
class GetUserUseCase {
  Future<Result<User>> getData(String id) async {
    // Implementation
  }
}

// ❌ WARNING 2: execute() con return type incorrecto  
class CreateUserUseCase {
  Future<void> execute(CreateUserParams params) async {
    // Should return Future<Result<void>>
  }
}

// ❌ WARNING 3: execute() retorna tipo directo
class UpdateUserUseCase {
  Future<User> execute(UpdateUserParams params) async {
    // Should return Future<Result<User>>
  }
}

// ❌ WARNING 4: execute() síncrono con tipo incorrecto
class ValidateUserUseCase {
  bool execute(String email) {
    // Should return Result<bool>
  }
}

// ❌ WARNING 5: execute() privado
class DeleteUserUseCase {
  Future<Result<void>> _execute(String id) async {
    // Should be public
  }
}
```

Crea `lib/test_valid_usecases.dart`:

```dart
// ESTE ARCHIVO NO DEBE GENERAR WARNINGS

// ✅ UseCase correcto asíncrono
class GetUserUseCase {
  Future<Result<User>> execute(String userId) async {
    // Implementation
    return Result.success(User());
  }
  
  // ✅ Métodos privados permitidos
  String _validateId(String id) => id.trim();
}

// ✅ UseCase correcto síncrono
class ValidateEmailUseCase {
  Result<bool> execute(String email) {
    return Result.success(email.contains('@'));
  }
}

// ✅ UseCase con parámetros complejos
class ProcessOrderUseCase {
  Future<Result<Order>> execute(ProcessOrderParams params) async {
    // Implementation
    return Result.success(Order());
  }
}

// ✅ UseCase con Result<void>
class DeleteUserUseCase {
  Future<Result<void>> execute(String userId) async {
    // Implementation
    return Result.success(null);
  }
}

// ✅ Abstract UseCase - no requiere implementación
abstract class BaseUseCase<T, P> {
  Future<Result<T>> execute(P params);
}

// ✅ Clases que no son UseCase - ignoradas
class UserService {
  Future<User> getUser(String id) async {
    // No es UseCase, no aplica la regla
  }
}

class UserRepository {
  User findById(String id) {
    // No es UseCase, no aplica la regla
  }
}
```

### Verificación

```bash
dart run custom_lint
```

**Resultado esperado**:
- `test_invalid_usecases.dart`: 5 warnings
- `test_valid_usecases.dart`: 0 warnings

### Testing avanzado

```dart
// Edge cases para verificar robustez
class AdvancedUseCaseTests {
  
  // ✅ Generic UseCase correcto
  class ProcessDataUseCase<T> {
    Future<Result<T>> execute(ProcessParams<T> params) async {
      // Generic implementation
    }
  }
  
  // ✅ UseCase con múltiples generic types
  class TransformUseCase<Input, Output> {
    Result<Output> execute(Input input) {
      // Transformation logic
    }
  }
  
  // ❌ Execute con generic incorrecto
  class BadGenericUseCase<T> {
    Future<T> execute(ProcessParams params) async { // Should be Future<Result<T>>
      // Implementation
    }
  }
}
```

## Configuración

Esta regla no requiere configuración. Se aplica automáticamente a:

- **Clases UseCase**: Cualquier clase cuyo nombre termine en "UseCase"
- **Métodos públicos**: Solo verifica métodos públicos (no privados/protected)
- **Clases concretas**: Abstract classes se ignoran

## Impacto en performance

- **Análisis**: Ligero - solo examina clases UseCase
- **Aplicación**: Alto beneficio - garantiza consistencia arquitectural
- **Falsos positivos**: Muy bajos - criterio específico y claro

## Excepciones automáticas

La regla **NO alerta** en estos casos:

1. **Abstract classes** - No requieren implementar execute()
2. **Métodos privados/protected** - Solo verifica métodos públicos
3. **Clases sin sufijo "UseCase"** - Solo aplica a UseCases
4. **Getters/setters** - Solo analiza métodos regulares

## Relación con otras reglas

- Complementa reglas de Clean Architecture
- Trabaja junto con dependency injection patterns
- Refuerza error handling consistency

## Referencias

- [Clean Architecture - Use Cases](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Result Pattern in Dart](https://pub.dev/packages/result_type)
- [Effective Error Handling](https://dart.dev/guides/language/effective-dart/usage#prefer-async-await-over-using-raw-futures)
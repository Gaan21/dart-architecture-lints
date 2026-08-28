# repository_methods_return_result

**Severidad**: `error`

## Descripción

Enforza que todos los métodos públicos de Repository retornen `Result<T>` o `Future<Result<T>>` para manejo consistente de errores.

## Motivación

Los Repositories son la capa que interactúa con DataSources y deben seguir el contrato de `Result<T>`:

1. **Manejo de errores estructurado**: Errores como `Failure(AppException)`, no excepciones no capturadas
2. **Contrato con UseCases**: UseCases esperan `Result<T>` para procesarlo con `handleResult()`
3. **Invariante arquitectural**: "UseCases **siempre** devuelven `Result<T>`" (02A_RESULT_PATTERNS.md:10) - Los Repositories, siendo llamados por UseCases, deben seguir el mismo contrato
4. **Trazabilidad**: Errores de red, base de datos, etc. son envueltos en `AppException` con códigos específicos

**Referencias**:

## Alcance

- **Archivos**: `lib/data/repositories/**/*.dart`
- **Detecta**: Métodos públicos en clases que terminan en `Repository` o `RepositoryImpl`
- **Excluye**:
  - Constructors
  - Métodos privados (comienzan con `_`)
  - Métodos abstractos (solo declaraciones de interface)
  - Getters síncronos (sin `Future`)
  - Métodos que retornan `void` o `Future<void>`
  - Métodos con `@override` de Object (`toString`, `hashCode`, `==`)

## Ejemplos

### ❌ Incorrecto

```dart
// lib/data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  final UserDataSource _dataSource;

  UserRepositoryImpl(this._dataSource);

  // ❌ Retorna User directamente sin Result<T>
  Future<User> getById(String id) async {
    final model = await _dataSource.getById(id);
    return UserMapper.toEntity(model);
  }

  // ❌ Retorna List<User> sin Result<T>
  Future<List<User>> getAll() async {
    final models = await _dataSource.getAll();
    return models.map(UserMapper.toEntity).toList();
  }
}
```

**Problemas**:
- Si `_dataSource.getById()` lanza excepción, se propaga sin estructura
- UseCase no puede usar `handleResult()` para actualizar UI automáticamente
- No hay distinción entre "usuario no encontrado" vs "error de red"

### ✅ Correcto

```dart
// lib/data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  final UserDataSource _dataSource;

  UserRepositoryImpl(this._dataSource);

  @override
  Future<Result<User>> getById(String id) async {
    try {
      final model = await _dataSource.getById(id);
      return Success(UserMapper.toEntity(model));
    } catch (e) {
      return Failure(AppException.fromException(e));
    }
  }

  @override
  Future<Result<List<User>>> getAll() async {
    try {
      final models = await _dataSource.getAll();
      final entities = models.map(UserMapper.toEntity).toList();
      return Success(entities);
    } catch (e) {
      return Failure(AppException.fromException(e));
    }
  }
}
```

**Beneficios**:
- Errores estructurados con `AppException`
- UseCase puede usar `handleResult()` directamente
- Trazabilidad: errores de red/DB distinguibles por código

### ✅ Correcto - Métodos excluidos

```dart
class UserRepositoryImpl implements UserRepository {
  final UserDataSource _dataSource;

  UserRepositoryImpl(this._dataSource); // ✅ Constructor - excluido

  // ✅ Getter síncrono - excluido
  bool get isInitialized => _dataSource.isInitialized;

  // ✅ Método void - excluido (configuración)
  Future<void> initialize() async {
    await _dataSource.initialize();
  }

  // ✅ Método privado - excluido
  String _buildCacheKey(String id) => 'user_$id';

  // ✅ Override de Object - excluido
  @override
  String toString() => 'UserRepositoryImpl';

  // ❌ Método público que retorna datos - DEBE usar Result<T>
  @override
  Future<Result<User>> getById(String id) async { /* ... */ }
}
```

## Implementación Técnica

### Heurística AST

```dart
// 1. Detectar clases en lib/data/repositories/
// 2. Solo clases que terminan en "Repository" o "RepositoryImpl"
// 3. Para cada método público:
//    a. Excluir: constructors, privados, abstractos, getters síncronos
//    b. Excluir: void, Future<void>, @override de Object
//    c. Verificar tipo de retorno:
//       - ✅ Result<T>
//       - ✅ Future<Result<T>>
//       - ❌ Cualquier otro tipo → reportar error
```

### Exclusiones aplicadas (ajuste Fase 2)

**Mejora respecto a spec original**:

La spec decía: "Excluir métodos que retornan `void` o tipos primitivos para configuración"

**Implementación final (más precisa)**:
- ✅ `void` y `Future<void>` - Métodos de configuración/inicialización
- ✅ Getters síncronos - No deberían retornar `Future<Result<T>>`
- ✅ Métodos con `@override` de Object - `toString`, `hashCode`, `==`
- ✅ Métodos privados - No forman parte del contrato público

**NO excluimos**:
- ❌ Tipos primitivos con `Future` (ej: `Future<int>`) - Deben retornar `Future<Result<int>>`
- ❌ Objetos de dominio sin `Future` (ej: `User`) - Poco común pero deben usar `Result<User>`

### Falsos positivos estimados

**~10-15%** (reducido desde ~15% original):

Casos legítimos:
- Métodos helper síncronos que retornan configuración simple
- Getters calculados de propiedades internas

**Solución**: Usar `// ignore: repository_methods_return_result` o hacer el método privado

## Testing Guide

### En un proyecto consumidor separado

1. **Crear Repository inválido**:
```dart
// lib/data/repositories/test_repository_impl.dart
class TestRepositoryImpl implements TestRepository {
  final TestDataSource _dataSource;

  TestRepositoryImpl(this._dataSource);

  // ❌ Sin Result<T>
  Future<String> getData(String id) async {
    return await _dataSource.getData(id);
  }
}
```

2. **Ejecutar linter**:
```bash
cd /path/to/proyecto_pruebas
dart run custom_lint
```

3. **Verificar detección**:
```
error • Los métodos de Repository deben retornar Future<Result<T>> o Result<T> para manejo de errores consistente. • lib/data/repositories/test_repository_impl.dart:6:3 • repository_methods_return_result
```

4. **Corregir y verificar**:
```dart
class TestRepositoryImpl implements TestRepository {
  final TestDataSource _dataSource;

  TestRepositoryImpl(this._dataSource);

  @override
  Future<Result<String>> getData(String id) async {
    try {
      final data = await _dataSource.getData(id);
      return Success(data);
    } catch (e) {
      return Failure(AppException.fromException(e));
    }
  }
}
```

5. **Confirmar fix**:
```bash
dart run custom_lint
# Sin errores de repository_methods_return_result
```

## Complementariedad

Esta regla completa el ecosistema de `Result<T>`:

1. ✅ `usecases_extend_base_usecase` (Fase 1B) - UseCases retornan Result<T>
2. ✅ `repository_methods_return_result` (ESTA REGLA) - Repositories retornan Result<T>
3. ✅ `no_result_throw` (existente) - Result<T> no lanza excepciones
4. ⏳ `datasources_return_result` (Fase 3) - DataSources retornan Result<T> (opcional)

**Cobertura**: Manejo de errores consistente desde DataSource → Repository → UseCase → ViewModel → UI

## Notas de Implementación

### Ajustes respecto a spec original

1. **Exclusiones más precisas**:
   - Spec decía "tipos primitivos para configuración" (vago)
   - Implementación: Solo `void` y `Future<void>` + getters síncronos + overrides de Object

2. **Detección mejorada**:
   - Detecta tanto `Result<T>` como `Future<Result<T>>`
   - Maneja getters con `Future` correctamente (deben retornar Result)

3. **Falsos positivos reducidos**: ~10-15% (vs ~15% estimado original)

### Casos edge conocidos

1. **Métodos de inicialización**: `Future<void> init()` es excluido correctamente
2. **Getters síncronos**: `bool get isReady` excluido, pero `Future<bool> get isReady` **NO** excluido (debe retornar `Future<Result<bool>>`)
3. **Métodos de batch**: `Future<List<User>> getMany()` debe retornar `Future<Result<List<User>>>`

### Pattern recomendado con Result<T>

```dart
// ✅ Pattern correcto: try-catch con Result<T>
Future<Result<T>> getData() async {
  try {
    final data = await _dataSource.getData();
    return Success(data);
  } on NetworkException catch (e) {
    return Failure(AppException.network(e.message));
  } on CacheException catch (e) {
    return Failure(AppException.cache(e.message));
  } catch (e) {
    return Failure(AppException.unknown(e.toString()));
  }
}

// ✅ Alternative: DataSource retorna Result<T> (Fase 3)
Future<Result<T>> getData() async {
  final result = await _dataSource.getData();
  return result.map(Mapper.toEntity);
}
```

## Referencias Técnicas

- **custom_lint API**: `ClassDeclaration`, `MethodDeclaration`, `TypeAnnotation`
- **Patrón similar**: `usecases_extend_base_usecase` (verificación de contratos)
- **Guideline**: `02A_RESULT_PATTERNS.md` - Result<T> pattern y BaseUseCase

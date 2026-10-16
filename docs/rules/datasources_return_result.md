<!-- example-scope: isolated datasources_return_result -->

> **Example contract: `datasources_return_result` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# datasources_return_result

**Severidad**: `warning`

## Descripción

Enforza que los métodos públicos de DataSources retornen `Future<Result<T>>`, `Result<T>`, o `Stream<Result<T>>` para manejo de errores consistente en la data layer.

## Motivación

Esta regla completa la cadena de Result<T> en toda la data layer:
- **UseCases** retornan `Result<T>` (enforced by `usecases_follow_pattern` + `usecases_extend_base_usecase`)
- **Repositories** retornan `Future<Result<T>>` (enforced by `repository_methods_return_result`)
- **DataSources** retornan `Future<Result<T>>` (enforced by **esta regla**)

Sin Result<T>, los errores en DataSources se propagan como excepciones raw, rompiendo el contrato de manejo de errores estructurado.

**Referencias**:
- Guideline: `02A_RESULT_PATTERNS.md:8, 02A_RESULT_PATTERNS.md:239-306`
- Invariante: "DataSources no exponen tipos de dominio ni UI; solo Models + Result<T>"

## Alcance

- **Archivos**: `lib/data/dataSources/` (incluyendo subcarpetas `local/`, `remote/`, y cualquier otra)
- **Detecta**: Métodos públicos en clases `DataSource` o `DataSourceImpl` que no retornan Result<T>
- **Excluye**:
  - Constructors
  - Métodos privados (\_methodName)
  - Getters síncronos simples (configuración)
  - Métodos `void`, `Future<void>`, `Stream<void>`
  - Overrides de Object (`toString`, `hashCode`, `==`)

## Ejemplos

### ❌ Incorrecto

```dart
// ❌ DataSource sin Result<T>
abstract interface class UserLocalDataSource {
  Future<List<UserModel>> getUsers();  // ❌ datasources_return_result
  Future<UserModel?> getById(int id);  // ❌ datasources_return_result
}

class UserLocalDataSourceImpl implements UserLocalDataSource {
  final Database _db;

  @override
  Future<List<UserModel>> getUsers() async {
    try {
      final rows = await _db.query('users');
      return rows.map(UserModel.fromRow).toList();
    } catch (e) {
      throw StorageException('Error: $e');  // ❌ Excepción raw
    }
  }

  @override
  Future<UserModel?> getById(int id) async {
    final rows = await _db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : UserModel.fromRow(rows.first);
  }
}
```

**Problemas**:
- Errores se propagan como excepciones, no Result<T>
- Repository debe manejar excepciones manualmente
- Inconsistente con resto de data layer
- Dificulta testing (mocks deben throw)

### ✅ Correcto

```dart
// ✅ DataSource con Result<T>
abstract interface class UserLocalDataSource {
  Future<Result<List<UserModel>>> getUsers();
  Future<Result<UserModel?>> getById(int id);
}

class UserLocalDataSourceImpl implements UserLocalDataSource {
  final Database _db;

  @override
  Future<Result<List<UserModel>>> getUsers() async {
    try {
      final rows = await _db.query('users');
      final models = rows.map(UserModel.fromRow).toList();
      return Success(models);
    } catch (e) {
      return Failure(StorageException('Failed to load users: $e'));
    }
  }

  @override
  Future<Result<UserModel?>> getById(int id) async {
    try {
      final rows = await _db.query('users', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return const Success(null);
      return Success(UserModel.fromRow(rows.first));
    } catch (e) {
      return Failure(StorageException('Failed to get user: $e'));
    }
  }
}
```

**Beneficios**:
- Errores estructurados con Result<T>
- Repository solo mapea Result sin try-catch
- Consistente con UseCases y Repositories
- Testing sencillo (return Failure en mocks)

### ✅ Correcto - Stream<Result<T>>

```dart
// ✅ Stream para escucha continua
abstract interface class OrderLocalDataSource {
  Stream<Result<List<OrderModel>>> watchOrders();  // ✅ Stream<Result<T>> válido
}

class OrderLocalDataSourceImpl implements OrderLocalDataSource {
  final Database _db;

  @override
  Stream<Result<List<OrderModel>>> watchOrders() async* {
    try {
      await for (final rows in _db.watch('orders')) {
        final models = rows.map(OrderModel.fromRow).toList();
        yield Success(models);
      }
    } catch (e) {
      yield Failure(StorageException('Watch failed: $e'));
    }
  }
}
```

### ✅ Correcto - Métodos excluidos

```dart
class UserLocalDataSourceImpl implements UserLocalDataSource {
  final Database _db;

  // ✅ Constructor - excluido
  UserLocalDataSourceImpl(this._db);

  // ✅ Método void - excluido (configuración)
  void clearCache() {
    // ...
  }

  // ✅ Getter síncrono - excluido (configuración)
  String get databasePath => _db.path;

  // ✅ Método privado - excluido
  Future<void> _migrate() async {
    // ...
  }

  // ✅ Override de Object - excluido
  @override
  String toString() => 'UserLocalDataSourceImpl($_db)';

  // ✅ Método que retorna Result<T>
  Future<Result<List<UserModel>>> getUsers() async {
    // ...
  }
}
```

## Implementación Técnica

### Heurística AST

```dart
// 1. Verificar que el archivo esté en data/dataSources/local/ o data/dataSources/remote/
// 2. Para cada ClassDeclaration:
//    - Verificar que el nombre termine en "DataSource" o "DataSourceImpl"
// 3. Para cada MethodDeclaration público (incluyendo abstractos):
//    - Excluir: constructors, privados, void, getters síncronos
//    - Verificar tipo de retorno: debe ser Future<Result<T>>, Result<T>, o Stream<Result<T>>
//    - Si NO retorna Result<T> → reportar warning
```

**Nota importante**: Esta regla **SÍ verifica métodos abstractos** en interfaces. Esto es correcto porque:
- Las interfaces definen el **contrato** que las implementaciones deben cumplir
- Si la interface declara `Future<List<Model>>` pero la implementación quiere retornar `Future<Result<List<Model>>>`, hay un **mismatch de tipos**
- Verificar ambas (interface e implementación) garantiza que todo el contrato usa Result<T> consistentemente

### Detección de Result<T>

La regla verifica el tipo de retorno del método:

```dart
// Válidos (no reportan warning):
Future<Result<List<UserModel>>> getUsers();
Result<UserModel> getCached();
Stream<Result<List<OrderModel>>> watchOrders();

// Inválidos (reportan warning):
Future<List<UserModel>> getUsers();  // ❌ datasources_return_result
Future<UserModel?> getById(int id);  // ❌ datasources_return_result
List<UserModel> getCached();         // ❌ datasources_return_result
```

### Falsos positivos estimados

**~20%** - Casos legítimos:
- Métodos de configuración internos (deben ser privados)
- Getters complejos sin Future/Stream (deben retornar Result<T> si fallan)
- Streams especiales para eventos (considerar Stream<Result<T>>)

**Solución**: Usar `// ignore: datasources_return_result` solo en casos excepcionales, o refactorizar para seguir el patrón.

## Testing Guide

### En un proyecto consumidor separado

1. **Crear DataSource sin Result<T>**:
```dart
// lib/data/dataSources/local/test_data_source.dart
abstract interface class TestDataSource {
  Future<List<String>> getData();  // ❌ datasources_return_result
}

class TestDataSourceImpl implements TestDataSource {
  @override
  Future<List<String>> getData() async {
    return ['item1', 'item2'];
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
warning • Los métodos de DataSource deben retornar Future<Result<T>>, Result<T>, o Stream<Result<T>> para manejo de errores consistente en la data layer. • lib/data/dataSources/local/test_data_source.dart:2:3 • datasources_return_result
warning • Los métodos de DataSource deben retornar Future<Result<T>>, Result<T>, o Stream<Result<T>> para manejo de errores consistente en la data layer. • lib/data/dataSources/local/test_data_source.dart:7:3 • datasources_return_result
```

4. **Corregir y verificar**:
```dart
// lib/data/dataSources/local/test_data_source.dart
abstract interface class TestDataSource {
  Future<Result<List<String>>> getData();  // ✅
}

class TestDataSourceImpl implements TestDataSource {
  @override
  Future<Result<List<String>>> getData() async {
    try {
      return Success(['item1', 'item2']);
    } catch (e) {
      return Failure(AppException('Failed: $e'));
    }
  }
}
```

5. **Confirmar fix**:
```bash
dart run custom_lint
# Sin warnings de datasources_return_result
```

## Complementariedad

Esta regla completa la cadena Result<T> en toda la arquitectura:

1. ✅ `usecases_follow_pattern` + `usecases_extend_base_usecase` - UseCases retornan Result<T>
2. ✅ `repository_methods_return_result` - Repositories retornan Future<Result<T>>
3. ✅ `datasources_return_result` (ESTA REGLA) - DataSources retornan Future<Result<T>>

**Flujo completo**:
```
DataSource → Repository → UseCase → ViewModel
Result<Model> → Result<Entity> → Result<Entity> → UiState<T>
```

**Resultado combinado**: Manejo de errores consistente y estructurado en toda la data layer, sin excepciones raw.

## Notas de Implementación

### Severidad: WARNING (no ERROR)

Esta regla usa `warning` (no `error`) porque:
- Falsos positivos estimados ~20% (métodos especiales, configuración)
- Algunos proyectos legacy pueden tener DataSources sin Result<T>
- Migración gradual permitida

**Promover a ERROR** si:
- Proyecto nuevo (sin código legacy)
- Falsos positivos < 10% tras calibración
- Team acuerda enforcing estricto

### Casos edge conocidos

1. **Métodos de configuración**: Deben ser privados o retornar void
   ```dart
   void configure(Config c) { }  // ✅ OK
   String get path => _path;      // ✅ OK (getter síncrono)
   ```

2. **Streams de eventos**: Considerar Stream<Result<T>>
   ```dart
   Stream<DatabaseEvent> watchChanges(); // Evaluar si debe ser Stream<Result<Event>>
   ```

3. **Cache synchronous**: Puede retornar Result<T> síncrono
   ```dart
   Result<UserModel?> getCached(String id);  // ✅ OK (Result síncrono)
   ```

## Referencias Técnicas

- **custom_lint API**: `ClassDeclaration`, `MethodDeclaration`, `TypeAnnotation`
- **AST inspection**: `returnType.name.lexeme` para verificar tipo de retorno
- **Patrón similar**: `repository_methods_return_result` (misma lógica, diferente scope)
- **Guidelines**: `02A_RESULT_PATTERNS.md:239-306`

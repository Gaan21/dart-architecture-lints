# require_explicit_types

**Severidad**: `error`

## Descripción

Enforza que todas las variables (fields, variables locales, loop variables) tengan type annotation explícita, prohibiendo type inference.

## Motivación

El tipado explícito es una guideline estricta del proyecto que proporciona múltiples beneficios:

1. **Legibilidad**: El tipo es inmediatamente visible sin necesidad de inferir o consultar inicializadores
2. **Compatibilidad con otras reglas**: `streamcontroller_must_close` y otras reglas AST requieren type annotations explícitas para funcionar correctamente
3. **Mantenibilidad**: Cambios en el inicializador no cambian silenciosamente el tipo del field
4. **Prevención de errores**: Type inference puede resultar en tipos más amplios de lo esperado (ej: `List` en lugar de `List<String>`)
5. **Consistencia**: Código uniforme en toda la codebase

**Referencias**:
- Guideline del proyecto: "Siempre tipar explícitamente"
- Complementa `enforce_final_variables` (prohibe `var`, enforza `final`)

## Alcance

- **Archivos**: Toda la codebase (`lib/**/*.dart`)
- **Detecta**: Variables sin type annotation explícita en:
  - Fields de clase (instance/static)
  - Variables locales en métodos
  - Loop variables (`for`, `for-in`)
- **Excluye**:
  - Parámetros de función (Dart require types en signatures)
  - Return types de métodos (ya verificado por Dart analyzer)
  - Variables `dynamic` explícitas (tienen type annotation)

## Ejemplos

### ❌ Incorrecto

```dart
// ❌ Fields sin type annotation
class UserRepository {
  final _dataSource = UserDataSource(); // ❌ Type inference
  final _cache = <String, User>{}; // ❌ Map inference
  final _controller = StreamController<String>(); // ❌ StreamController inference

  static final instance = UserRepository._(); // ❌ Static field inference
}

// ❌ Variables locales sin type annotation
class UserViewModel extends BaseViewModel<User> {
  Future<void> loadUser() async {
    final result = await _useCase.execute(); // ❌ Result inference
    final user = result.data; // ❌ User inference

    for (var i = 0; i < 10; i++) { // ❌ Loop variable inference
      print(i);
    }

    for (var user in users) { // ❌ For-in variable inference
      print(user.name);
    }
  }
}

// ❌ Variables con valores literales
class ConfigService {
  final maxRetries = 3; // ❌ int inference
  final timeout = 5000; // ❌ int inference
  final isEnabled = true; // ❌ bool inference
  final apiUrl = 'https://api.example.com'; // ❌ String inference
}
```

**Problemas**:
- Tipo no visible sin inspeccionar inicializador
- `streamcontroller_must_close` NO detectaría `_controller` sin type annotation
- Cambiar inicializador puede cambiar tipo silenciosamente
- Dificulta lectura rápida del código

### ✅ Correcto

```dart
// ✅ Fields con type annotations explícitas
class UserRepository {
  final UserDataSource _dataSource = UserDataSource(); // ✅ Type explícito
  final Map<String, User> _cache = {}; // ✅ Map tipado
  final StreamController<String> _controller = StreamController<String>(); // ✅ StreamController tipado

  static final UserRepository instance = UserRepository._(); // ✅ Static tipado
}

// ✅ Variables locales con type annotations explícitas
class UserViewModel extends BaseViewModel<User> {
  Future<void> loadUser() async {
    final Result<User> result = await _useCase.execute(); // ✅ Result tipado
    final User? user = result.data; // ✅ User nullable tipado

    for (int i = 0; i < 10; i++) { // ✅ Loop variable tipada
      print(i);
    }

    for (final User user in users) { // ✅ For-in variable tipada
      print(user.name);
    }
  }
}

// ✅ Variables con type annotations, incluso literales
class ConfigService {
  final int maxRetries = 3; // ✅ int explícito
  final int timeout = 5000; // ✅ int explícito
  final bool isEnabled = true; // ✅ bool explícito
  final String apiUrl = 'https://api.example.com'; // ✅ String explícito
}
```

**Beneficios**:
- Tipo inmediatamente visible
- Compatible con todas las reglas AST
- Cambios en inicializador no afectan tipo
- Código auto-documentado

### ✅ Correcto - Casos edge

```dart
class EdgeCases {
  // ✅ dynamic explícito - permitido (tiene type annotation)
  final dynamic flexibleValue = getSomeValue();

  // ✅ Parámetros de función - excluidos (Dart los require)
  void processUser(String userId) { } // ✅ No necesita annotation adicional

  // ✅ Return types - excluidos (ya verificado por analyzer)
  Future<Result<User>> getUser() async { } // ✅ Return type explícito

  // ✅ Type annotation con inicializador complejo
  final Future<List<User>> usersFuture = _loadUsers();
}
```

## Implementación Técnica

### Heurística AST

```dart
// 1. Para cada FieldDeclaration en el archivo:
//    a. Verificar si field.fields.type == null
//    b. Si es null → reportar error (type inference)
//    c. Si no es null → permitir (type annotation explícita)
//
// 2. Para cada VariableDeclarationStatement en métodos:
//    a. Verificar si variable.type == null
//    b. Si es null → reportar error (type inference)
//
// 3. Para cada ForStatement/ForEachStatement:
//    a. Verificar si loop variable tiene type annotation
//    b. Si es null → reportar error
```

### Detección de type inference

La regla detecta variables declaradas sin type annotation:

```dart
// field.fields.type == null → Type inference ❌
final _data = getData();

// field.fields.type != null → Type annotation ✅
final String _data = getData();
```

### Sin exclusiones - Máxima restricción

A diferencia de otras reglas, esta NO excluye:
- ❌ Variables con literales simples (`final x = 0;` → debe ser `final int x = 0;`)
- ❌ Variables privadas (aplica igual que públicas)
- ❌ Variables en tests (aplica en toda la codebase)

**Razón**: Guideline estricta de tipado explícito en TODO el código.

### Falsos positivos estimados

**< 5%** - Casos legítimos muy raros:
- Closures complejas donde el tipo inferido es muy largo
- Builders con tipos genéricos anidados

**Solución**: Usar `// ignore: require_explicit_types` solo en casos verdaderamente excepcionales.

## Testing Guide

### En un proyecto consumidor separado

1. **Crear archivo con type inference**:
```dart
// lib/test_types.dart
class TestTypes {
  final _controller = StreamController<String>(); // ❌
  final _count = 0; // ❌

  void test() {
    final data = getData(); // ❌
    for (var i = 0; i < 10; i++) { } // ❌
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
error • Variables must have explicit type annotations. Use 'final Type name = value;' instead of type inference. • lib/test_types.dart:2:3 • require_explicit_types
error • Variables must have explicit type annotations. Use 'final Type name = value;' instead of type inference. • lib/test_types.dart:3:3 • require_explicit_types
error • Variables must have explicit type annotations. Use 'int i' instead of 'var i'. • lib/test_types.dart:6:10 • require_explicit_types
error • Variables must have explicit type annotations. Use 'final Type name = value;' instead of type inference. • lib/test_types.dart:5:5 • require_explicit_types
```

4. **Corregir y verificar**:
```dart
// lib/test_types.dart
class TestTypes {
  final StreamController<String> _controller = StreamController<String>(); // ✅
  final int _count = 0; // ✅

  void test() {
    final String data = getData(); // ✅
    for (int i = 0; i < 10; i++) { } // ✅
  }
}
```

5. **Confirmar fix**:
```bash
dart run custom_lint
# Sin errores de require_explicit_types
```

### Caso con múltiples variables

```dart
// ❌ Detecta todas las variables sin type
class MultiVariables {
  final _a = 1; // ← Error
  final _b = 'text'; // ← Error
  final _c = []; // ← Error

  void process() {
    final x = 0; // ← Error
    final y = ''; // ← Error
  }
}
```

## Complementariedad

Esta regla trabaja en conjunto con otras reglas de estilo:

1. ✅ `enforce_final_variables` (existente) - Prohibe `var`, enforza `final`
2. ✅ `require_explicit_types` (ESTA REGLA) - Enforza type annotations explícitas
3. ✅ `streamcontroller_must_close` (existente) - Requiere type annotations para detectar StreamControllers

**Resultado combinado**: `final Type name = value;` en toda la codebase

**Flujo de enforzamiento**:
```
enforce_final_variables → var x = 0; ❌ → final x = 0; ⚠️
require_explicit_types → final x = 0; ❌ → final int x = 0; ✅
```

## Beneficio para `streamcontroller_must_close`

**Problema original**: `streamcontroller_must_close` solo detectaba StreamControllers con type annotation explícita.

**Solución con esta regla**:
```dart
// Antes (NO detectado por streamcontroller_must_close)
class MyViewModel {
  final _controller = StreamController<String>(); // ❌ require_explicit_types

  void dispose() {
    // Falta close() pero streamcontroller_must_close NO lo detecta
  }
}

// Después (DETECTADO correctamente)
class MyViewModel {
  final StreamController<String> _controller = StreamController<String>(); // ✅

  void dispose() {
    // streamcontroller_must_close AHORA SÍ detecta que falta close()
  }
}
```

**Cobertura completa**: Con ambas reglas, NO hay StreamControllers sin close.

## Notas de Implementación

### Scope de detección

```dart
// ✅ DETECTA estos casos:
class MyClass {
  final field = value; // ← Field sin type
  static final staticField = value; // ← Static field sin type

  void method() {
    final local = value; // ← Variable local sin type
    for (var i = 0; i < 10; i++) { } // ← Loop variable sin type
    for (var item in list) { } // ← For-in variable sin type
  }
}

// ✅ NO DETECTA (ya correctos o fuera de scope):
void function(String param) { } // ← Parámetro con type
Future<String> getData() { } // ← Return type explícito
final dynamic value = something; // ← dynamic es type annotation
```

### Casos edge conocidos

1. **Closures anónimas**: Parámetros de closures pueden inferirse (fuera de scope)
   ```dart
   list.map((e) => e.name); // ✅ OK - parámetro de closure
   ```

2. **Pattern matching** (Dart 3.x): Variables en patterns pueden inferirse (fuera de scope inicial)
   ```dart
   if (value case int x) { } // Depende de implementación
   ```

3. **Destructuring**: Requiere investigación adicional
   ```dart
   final (a, b) = getTuple(); // Puede requerir type annotation
   ```

### Pattern recomendado

```dart
// ✅ Pattern estricto recomendado
class MyClass {
  // Fields: final Type name = initializer;
  final StreamController<String> _controller = StreamController<String>();
  final Map<String, User> _cache = {};
  final int _count = 0;

  // Métodos: final Type name = expression;
  Future<void> process() async {
    final Result<User> result = await _useCase.execute();
    final User? user = result.data;

    // Loops: Type variable
    for (int i = 0; i < 10; i++) { }
    for (final User user in users) { }
  }
}
```

## Referencias Técnicas

- **custom_lint API**: `FieldDeclaration`, `VariableDeclarationStatement`, `ForStatement`
- **AST inspection**: `field.fields.type` para detectar type annotation
- **Patrón similar**: Ninguna regla existente (nueva categoría)
- **Guideline**: Tipado explícito como estándar del proyecto

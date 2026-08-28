# streamcontroller_must_close

**Severidad**: `error`

## Descripción

Enforza que todos los `StreamController` fields sean cerrados en el método `dispose()` para prevenir memory leaks.

## Motivación

Los StreamControllers abiertos acumulan listeners y recursos que causan memory leaks:

1. **Memory leak crítico**: StreamControllers no cerrados mantienen referencias activas
2. **Pattern común**: Usado en `BaseViewModelWithEffects` para `UiEffect` streams
3. **Fácil de olvidar**: Agentes implementan StreamController pero olvidan `.close()` en dispose
4. **Impacto acumulativo**: En apps con muchas pantallas, los leaks se acumulan rápidamente

**Referencias**:
- Similar a `viewmodels_call_super_dispose` - Prevención de memory leaks

## Alcance

- **Archivos**: `lib/presentation/viewModels/**/*.dart` O clases que extienden ChangeNotifier/BaseViewModel
- **Detecta**: Fields de tipo `StreamController<T>` sin llamada a `.close()` en `dispose()`
- **Excluye**:
  - StreamControllers inyectados en constructor (gestionados externamente)
  - Con comentario `// ignore: streamcontroller_must_close`

## Ejemplos

### ❌ Incorrecto

```dart
// lib/presentation/viewModels/user_view_model.dart
class UserViewModel extends BaseViewModelWithEffects<User> {
  final _effects = StreamController<UiEffect>.broadcast();
  Stream<UiEffect> get uiEffects => _effects.stream;

  final GetUserUseCase _getUserUseCase;

  UserViewModel(this._getUserUseCase);

  Future<void> deleteUser(String id) async {
    final result = await _getUserUseCase.execute(id);
    result.when(
      success: (_) {
        _effects.add(UiEffect.showSuccess('deleted'.tr()));
        _effects.add(UiEffect.navigateBack());
      },
      failure: (error) => setState(UiState.error(error)),
    );
  }

  @override
  void dispose() {
    // ❌ Falta cerrar _effects StreamController
    super.dispose();
  }
}
```

**Problema**: `_effects` StreamController nunca se cierra → memory leak

### ✅ Correcto

```dart
// lib/presentation/viewModels/user_view_model.dart
class UserViewModel extends BaseViewModelWithEffects<User> {
  final _effects = StreamController<UiEffect>.broadcast();
  Stream<UiEffect> get uiEffects => _effects.stream;

  final GetUserUseCase _getUserUseCase;

  UserViewModel(this._getUserUseCase);

  Future<void> deleteUser(String id) async {
    final result = await _getUserUseCase.execute(id);
    result.when(
      success: (_) {
        _effects.add(UiEffect.showSuccess('deleted'.tr()));
        _effects.add(UiEffect.navigateBack());
      },
      failure: (error) => setState(UiState.error(error)),
    );
  }

  @override
  void dispose() {
    _effects.close(); // ✅ Cierra antes de super.dispose()
    super.dispose();
  }
}
```

### ✅ Correcto - Múltiples StreamControllers

```dart
class ComplexViewModel extends BaseViewModel<List<Item>> {
  final _searchController = StreamController<String>();
  final _filterController = StreamController<FilterState>();

  Stream<String> get searchStream => _searchController.stream;
  Stream<FilterState> get filterStream => _filterController.stream;

  @override
  void dispose() {
    _searchController.close(); // ✅ Cierra todos
    _filterController.close();
    super.dispose();
  }
}
```

### ✅ Correcto - Variantes de .close()

```dart
class MyViewModel extends ChangeNotifier {
  final _controller = StreamController<String>.broadcast();

  @override
  void dispose() {
    // ✅ Todas estas variantes son válidas:

    // 1. Simple
    _controller.close();

    // 2. Con await
    await _controller.close();

    // 3. Null-aware (si es nullable)
    _controller?.close();

    // 4. En try-finally
    try {
      // cleanup
    } finally {
      _controller.close();
    }

    super.dispose();
  }
}
```

### ✅ Correcto - StreamController gestionado externamente

```dart
class MyViewModel extends ChangeNotifier {
  final StreamController<String> _externalController;

  // StreamController inyectado → gestionado externamente
  // ignore: streamcontroller_must_close
  MyViewModel(this._externalController);

  @override
  void dispose() {
    // No cerramos _externalController (no es responsabilidad de esta clase)
    super.dispose();
  }
}
```

## Implementación Técnica

### Heurística AST

```dart
// 1. Detectar clases que deben verificarse:
//    a. Están en lib/presentation/viewModels/
//    b. O extienden ChangeNotifier, BaseViewModel, BaseViewModelWithEffects
//
// 2. Recopilar fields de tipo StreamController<T>
//
// 3. Para cada StreamController field:
//    a. Buscar método dispose() en la clase
//    b. Verificar que dispose() contiene llamada a fieldName.close()
//    c. Aceptar: .close(), await .close(), ?.close()
//    d. Buscar en: statements directos, if, try-catch-finally
//
// 4. Si dispose() no existe o no llama .close() → reportar error
```

### Exclusiones aplicadas (ajuste Fase 2)

**Mejora respecto a spec original**:

La spec decía: "Clases en `lib/presentation/viewModels/` y otras con ChangeNotifier"

**Implementación final (más precisa)**:
- ✅ Clases en `lib/presentation/viewModels/**/*.dart` (siempre)
- ✅ Clases que extienden `ChangeNotifier`, `BaseViewModel`, `BaseViewModelWithEffects` (en cualquier ubicación)

**Detección mejorada de `.close()`**:
- ✅ `_controller.close()` - Simple
- ✅ `await _controller.close()` - Con await
- ✅ `_controller?.close()` - Null-aware
- ✅ Dentro de `if`, `try-catch`, `try-finally` - Contextos anidados

**Exclusión manual**:
- ✅ Comentario `// ignore: streamcontroller_must_close` para controllers inyectados

### Falsos positivos estimados

**~10%**:

Casos legítimos:
1. StreamControllers inyectados en constructor (gestionados por otra clase)
2. StreamControllers con ciclo de vida gestionado por lógica externa

**Solución**: Usar `// ignore: streamcontroller_must_close` con comentario explicativo

## Testing Guide

### En un proyecto consumidor separado

1. **Crear ViewModel con StreamController sin cerrar**:
```dart
// lib/presentation/viewModels/test_view_model.dart
class TestViewModel extends ChangeNotifier {
  final _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  void addEvent(String event) {
    _controller.add(event);
  }

  @override
  void dispose() {
    // ❌ Falta _controller.close()
    super.dispose();
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
error • StreamController debe cerrarse en dispose() para evitar memory leaks. • lib/presentation/viewModels/test_view_model.dart:2:3 • streamcontroller_must_close
```

4. **Corregir y verificar**:
```dart
class TestViewModel extends ChangeNotifier {
  final _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  void addEvent(String event) {
    _controller.add(event);
  }

  @override
  void dispose() {
    _controller.close(); // ✅ Agregado
    super.dispose();
  }
}
```

5. **Confirmar fix**:
```bash
dart run custom_lint
# Sin errores de streamcontroller_must_close
```

### Caso con múltiples StreamControllers

```dart
// ❌ Detecta todos los que faltan
class MultiStreamViewModel extends ChangeNotifier {
  final _stream1 = StreamController<int>();   // ← Error aquí
  final _stream2 = StreamController<String>(); // ← Error aquí

  @override
  void dispose() {
    _stream1.close(); // ✅ Solo este se cierra
    // ❌ Falta _stream2.close()
    super.dispose();
  }
}
```

## Complementariedad

Esta regla complementa otras de prevención de memory leaks:

1. ✅ `viewmodels_call_super_dispose` (existente) - Enforza super.dispose() en ViewModels
2. ✅ `uistate_must_call_super_dispose` (existente) - Enforza super.dispose() en UiState
3. ✅ `streamcontroller_must_close` (ESTA REGLA) - Enforza .close() en StreamControllers

**Cobertura completa**: ViewModels sin memory leaks (dispose correcto + streams cerrados)

## Notas de Implementación

### Ajustes respecto a spec original

1. **Alcance refinado**:
   - Spec: "Clases en `lib/presentation/viewModels/` y otras con ChangeNotifier" (vago)
   - Implementación: Criterios precisos (directorio O herencia de ChangeNotifier/BaseViewModel)

2. **Detección mejorada de `.close()`**:
   - Spec: "Buscar invocación `fieldName.close()` dentro de `dispose()`"
   - Implementación: Acepta await, null-aware (?), contextos anidados (if, try-catch)

3. **Recursión en AST**: Busca `.close()` en bloques anidados (try-finally, if-else)

### Casos edge conocidos

1. **StreamController nullable**: `StreamController<T>? _controller` → Debe usar `_controller?.close()` o `_controller.close()` si garantiza no-null
2. **Múltiples StreamControllers**: Cada uno debe cerrarse individualmente
3. **StreamController en field inicializado con late**: `late final _controller = ...` → Debe cerrarse igual
4. **Sin método dispose()**: Si la clase no tiene `dispose()`, reporta error en todos los StreamControllers

### Pattern recomendado

```dart
// ✅ Pattern correcto con BaseViewModelWithEffects
abstract class BaseViewModelWithEffects<T> extends BaseViewModel<T> {
  final _effects = StreamController<UiEffect>.broadcast();
  Stream<UiEffect> get uiEffects => _effects.stream;

  @protected
  void emit(UiEffect effect) {
    if (!isDisposed) _effects.add(effect);
  }

  @override
  void dispose() {
    _effects.close(); // ✅ Cierra stream antes de dispose
    super.dispose();
  }
}

// ViewModels que extienden BaseViewModelWithEffects heredan el close automático
class UserViewModel extends BaseViewModelWithEffects<User> {
  @override
  void dispose() {
    // No necesitan cerrar _effects (lo hace BaseViewModelWithEffects)
    super.dispose();
  }
}
```

## Referencias Técnicas

- **custom_lint API**: `ClassDeclaration`, `FieldDeclaration`, `MethodDeclaration`, `MethodInvocation`
- **Patrón similar**: `viewmodels_call_super_dispose` (búsqueda de llamadas en dispose)
- **Guideline**: `02B_UI_PATTERNS.md` - BaseViewModelWithEffects con UiEffects stream

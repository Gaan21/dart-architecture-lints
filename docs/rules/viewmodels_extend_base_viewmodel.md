# viewmodels_extend_base_viewmodel

**Severidad**: `error`

## Descripción

Enforza que todos los ViewModels extiendan `BaseViewModel<T>` o `BaseViewModelWithEffects<T>` en lugar de `ChangeNotifier` directamente u otras clases.

## Motivación

Los ViewModels deben seguir el patrón de estado tipado con `UiState<T>` para:

1. **Estado tipado y consistente**: `UiState<T>` proporciona estados claros (idle, loading, data, error, empty)
2. **Helpers integrados**: `setState()`, `handleResult()` para manejo automático de Result<T>
3. **Prevención de errores**: Check de `isDisposed` antes de actualizar estado
4. **Separación de concerns**: ViewModels con efectos usan `BaseViewModelWithEffects<T>`

**Referencias**:

## Alcance

- **Archivos**: `lib/presentation/viewModels/**/*.dart`
- **Detecta**: Clases que terminan en `ViewModel` y extienden `ChangeNotifier` u otras clases
- **Excluye**:
  - Clases abstractas (bases personalizadas)
  - Clases privadas (comienzan con `_`)
  - Clases que ya extienden `BaseViewModel<T>` o `BaseViewModelWithEffects<T>`

## Ejemplos

### ❌ Incorrecto

```dart
// lib/presentation/viewModels/user_view_model.dart
class UserViewModel extends ChangeNotifier {
  User? _user;
  bool _loading = false;

  void loadUser() {
    _loading = true;
    notifyListeners();
    // Manejo manual de estado
  }

  @override
  void dispose() {
    super.dispose();
  }
}
```

**Problema**:
- Extiende `ChangeNotifier` directamente
- Manejo manual de estado (booleanos, null checks)
- Sin estado tipado ni helpers

### ✅ Correcto - BaseViewModel

```dart
// lib/presentation/viewModels/user_view_model.dart
class UserViewModel extends BaseViewModel<User> {
  final GetUserUseCase _getUserUseCase;

  UserViewModel(this._getUserUseCase);

  Future<void> loadUser() async {
    setState(UiState.loading());
    final result = await _getUserUseCase.execute(NoParams());
    handleResult(result); // Automáticamente actualiza a data/error
  }

  @override
  void dispose() {
    super.dispose();
  }
}
```

**Beneficios**:
- Estado tipado con `UiState<User>`
- Helpers `setState()` y `handleResult()`
- Check automático de `isDisposed`

### ✅ Correcto - BaseViewModelWithEffects

```dart
// lib/presentation/viewModels/user_view_model.dart
class UserViewModel extends BaseViewModelWithEffects<User> {
  final DeleteUserUseCase _deleteUseCase;

  UserViewModel(this._deleteUseCase);

  Future<void> deleteUser(String userId) async {
    setState(UiState.loading());
    final result = await _deleteUseCase.execute(userId);

    result.when(
      success: (_) {
        emit(UiEffect.showSuccess('user.deleted'.tr()));
        emit(UiEffect.navigateBack());
      },
      failure: (error) => setState(UiState.error(error)),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
```

**Cuándo usar `BaseViewModelWithEffects`**:
- Necesitas emitir efectos efímeros (navegación, snackbars, toasts)
- Separar estado persistente (`UiState<T>`) de efectos one-shot (`UiEffect`)

## Implementación Técnica

### Heurística AST

```dart
// 1. Detectar clases en lib/presentation/viewModels/
// 2. Solo clases públicas que terminan en "ViewModel"
// 3. Verificar cláusula extends:
//    - ✅ BaseViewModel<T>
//    - ✅ BaseViewModelWithEffects<T>
//    - ❌ ChangeNotifier (reportar error)
//    - ❌ Cualquier otra clase (reportar error)
```

### Exclusiones aplicadas

- ✅ Clases abstractas (`abstract class BaseMyViewModel`)
- ✅ Clases privadas (`class _InternalViewModel`)
- ✅ Archivos fuera de `lib/presentation/viewModels/`

### Falsos positivos estimados

**< 15%** - Principalmente ViewModels legacy o casos edge:
- ViewModels que extienden bases personalizadas intermedias
- Helpers de testing que no son ViewModels reales

**Solución**: Usar `// ignore: viewmodels_extend_base_viewmodel` si el caso es legítimo

## Testing Guide

### En un proyecto consumidor separado

1. **Crear ViewModel inválido**:
```dart
// lib/presentation/viewModels/test_view_model.dart
class TestViewModel extends ChangeNotifier {
  void doSomething() {
    notifyListeners();
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
error • Los ViewModels deben extender BaseViewModel<T> o BaseViewModelWithEffects<T> para estado tipado y manejo consistente. • lib/presentation/viewModels/test_view_model.dart:1:1 • viewmodels_extend_base_viewmodel
```

4. **Corregir y verificar**:
```dart
class TestViewModel extends BaseViewModel<String> {
  void doSomething() {
    setState(UiState.data('test'));
  }
}
```

5. **Confirmar fix**:
```bash
dart run custom_lint
# Sin errores de viewmodels_extend_base_viewmodel
```

## Complementariedad

Esta regla completa el set de validación de ViewModels:

1. ✅ `viewmodels_extend_base_viewmodel` - Herencia correcta (ESTA REGLA)
2. ✅ `viewmodels_no_buildcontext` - Sin BuildContext en ViewModels
3. ✅ `viewmodels_no_flutter_types` - Sin tipos Flutter (Widget, Color, etc.)
4. ✅ `viewmodels_call_super_dispose` - Dispose correcto con super.dispose()

**Cobertura completa**: ViewModels arquitecturalmente correctos, testeables y sin memory leaks.

## Notas de Implementación

### Ajustes respecto a spec original

1. **Detección mejorada**: Acepta tanto `BaseViewModel<T>` como `BaseViewModelWithEffects<T>`
2. **Alcance preciso**: Solo `lib/presentation/viewModels/`, evita falsos positivos en otros directorios
3. **Mensajes accionables**: Incluye ejemplos completos en `correctionMessage`

### Casos edge conocidos

- **ViewModels con bases intermedias**: Si tienes `class MyBaseViewModel extends BaseViewModel` y luego `class UserViewModel extends MyBaseViewModel`, la regla reportará error. Marca `MyBaseViewModel` como `abstract` o usa `// ignore`.

## Referencias Técnicas

- **custom_lint API**: `ClassDeclaration`, `ExtendsClause`
- **Patrón similar**: `usecases_extend_base_usecase` (Fase 1B)
- **Guideline**: `02B_UI_PATTERNS.md` - BaseViewModel y BaseViewModelWithEffects

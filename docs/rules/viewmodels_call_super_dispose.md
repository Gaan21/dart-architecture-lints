<!-- example-scope: isolated viewmodels_call_super_dispose -->

> **Example contract: `viewmodels_call_super_dispose` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# viewmodels_call_super_dispose

**Nivel**: CRÍTICO | **Tipo**: Architecture/Memory Management | **Área**: ViewModel Lifecycle

## Descripción

Esta regla asegura que todos los ViewModels que implementan el método `dispose()` llamen a `super.dispose()`. Esto es crítico para el manejo adecuado del lifecycle y prevención de memory leaks en arquitecturas MVVM.

## ¿Por qué es importante?

- **Memory leaks**: Sin `super.dispose()` los recursos del ViewModel padre no se liberan
- **Resource cleanup**: Garantiza limpieza completa de subscriptions, streams, controllers
- **Architecture consistency**: Mantiene el contrato de dispose en toda la jerarquía
- **Debugging**: Facilita identificar problemas de memoria en desarrollo

## Ejemplos

### ✅ Código correcto (no debe alertar)

```dart
// ViewModel con super.dispose() correcto
class UserViewModel extends BaseViewModel {
  late StreamSubscription _subscription;
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose(); // ✅ Llamada correcta a super.dispose()
  }
}

// ChangeNotifier con cleanup adecuado
class NotificationViewModel extends ChangeNotifier {
  Timer? _timer;
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose(); // ✅ Limpieza correcta
  }
}

// ViewModels sin dispose() - no se aplica la regla
class ReadOnlyViewModel extends BaseViewModel {
  // Sin dispose() - no hay problema
}

// Método abstracto - no se aplica
abstract class BaseViewModel {
  void dispose(); // ✅ Abstracto, no requiere implementación
}
```

### ❌ Código incorrecto (debe alertar)

```dart
// Falta super.dispose()
class UserViewModel extends BaseViewModel {
  late StreamController _controller;
  
  @override
  void dispose() {
    _controller.close();
    // ❌ Falta super.dispose()
  }
}

// ChangeNotifier sin super.dispose()
class CounterViewModel extends ChangeNotifier {
  @override
  void dispose() {
    // Limpieza local
    _resetValues();
    // ❌ Falta super.dispose()
  }
}

// Cubit sin limpieza adecuada
class AuthCubit extends Cubit<AuthState> {
  @override
  void close() {
    // Limpieza personalizada
    _clearTokens();
    // ❌ Debería llamar super.close() (equivalente para Cubit)
  }
}
```

## Casos detectados

La regla identifica:

1. **Classes extending ViewModel types**: BaseViewModel, ChangeNotifier, ValueNotifier, Cubit, Bloc
2. **dispose() method implementations**: Métodos concretos (no abstractos)
3. **Missing super.dispose() calls**: Análisis del body del método
4. **Control flow aware**: Detecta super.dispose() en if/try-catch/finally blocks

## Clases monitoreadas

La regla aplica a clases que extienden:

- `ViewModel`, `BaseViewModel` (custom base classes)
- `ChangeNotifier`, `ValueNotifier` (Flutter/Dart built-in)
- `Cubit`, `Bloc` (BLoC pattern)
- Cualquier clase con "ViewModel", "Model", "Controller", "Provider" en el nombre

## Testing guide

### Setup de testing

Crea un proyecto de prueba:

```bash
flutter create test_viewmodel_project
cd test_viewmodel_project
```

### Configuración del linter

En `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.3

dev_dependencies:
  dart_architecture_lints: ^0.0.1
  custom_lint: ^0.6.0
```

En `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    - viewmodels_call_super_dispose
```

### Casos de prueba

Crea `lib/test_viewmodels.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Base classes para testing
abstract class BaseViewModel extends ChangeNotifier {
  @override
  void dispose() {
    print('BaseViewModel disposing');
    super.dispose();
  }
}

class CustomProvider extends ChangeNotifier {
  void cleanup() {
    print('Custom cleanup');
  }
}

// Test cases - ESTOS DEBEN ALERTAR
class BadUserViewModel extends BaseViewModel {
  @override
  void dispose() {
    print('User cleanup');
    // ❌ Falta super.dispose()
  }
}

class BadNotificationProvider extends CustomProvider {
  @override
  void dispose() {
    cleanup();
    // ❌ Falta super.dispose()  
  }
}

class BadAuthCubit extends Cubit<String> {
  BadAuthCubit() : super('initial');
  
  @override
  void close() {
    print('Auth cleanup');
    // ❌ Falta super.close()
  }
}

// Test cases - ESTOS NO DEBEN ALERTAR
class GoodUserViewModel extends BaseViewModel {
  @override
  void dispose() {
    print('User cleanup');
    super.dispose(); // ✅ Correcto
  }
}

class GoodCounterProvider extends ChangeNotifier {
  @override
  void dispose() {
    super.dispose(); // ✅ Correcto
  }
}

class NoDisposeViewModel extends BaseViewModel {
  // ✅ No implementa dispose - no aplica regla
}

// Edge cases
class ConditionalDisposeViewModel extends BaseViewModel {
  bool _disposed = false;
  
  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      super.dispose(); // ✅ En conditional - debe detectarse
    }
  }
}

class TryCatchViewModel extends BaseViewModel {
  @override
  void dispose() {
    try {
      // cleanup logic
    } finally {
      super.dispose(); // ✅ En finally - debe detectarse
    }
  }
}
```

### Verificación

Ejecuta el análisis:

```bash
dart run custom_lint
```

**Resultado esperado**: 
- 3 warnings para BadUserViewModel, BadNotificationProvider, BadAuthCubit
- 0 warnings para los casos "Good" y edge cases correctos

### Testing avanzado

```dart
// Casos complejos para verificar robustez
class ComplexViewModel extends BaseViewModel {
  StreamSubscription? _sub1;
  StreamSubscription? _sub2;
  Timer? _timer;
  
  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    _timer?.cancel();
    
    if (_someCondition()) {
      _extraCleanup();
    }
    
    try {
      _riskyCleanup();
    } catch (e) {
      print('Cleanup error: $e');
    } finally {
      super.dispose(); // ✅ Debe detectarse en finally
    }
  }
}

class MultipleCallsViewModel extends BaseViewModel {
  @override  
  void dispose() {
    super.dispose(); // ✅ Primera llamada válida
    // Múltiples llamadas no son error en esta regla
    super.dispose(); // No es ideal pero no debe alertar
  }
}
```

## Configuración

Esta regla no requiere configuración adicional y se ejecuta automáticamente en:

- Clases que extienden tipos ViewModel conocidos
- Métodos `dispose()` concretos (no abstractos)
- Archivos no generados o de test

## Impacto en performance

- **Análisis**: Mínimo - solo examina métodos dispose
- **Aplicación**: Alto beneficio - previene memory leaks críticos
- **Falsos positivos**: Muy raros - lógica conservadora

## Relación con otras reglas

- Complementa reglas de lifecycle management
- No interfiere con reglas de naming o structure
- Trabaja junto con memory leak prevention rules

## Referencias

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [ChangeNotifier Documentation](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html)
- [BLoC Pattern Lifecycle](https://bloclibrary.dev/#/architecture)
- [Memory Management in Flutter](https://docs.flutter.dev/perf/memory)

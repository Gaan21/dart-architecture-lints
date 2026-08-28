# uistate_must_call_super_dispose

**Nivel**: CRÍTICO | **Tipo**: State Management | **Área**: UiState Lifecycle

## Descripción

Garantiza que todas las clases `*UiState` que sobrescriben `dispose()` llamen a `super.dispose()`. Los UiState son responsables de manejar `TextEditingController`, `Timer`, `FocusNode` y otros recursos con lifecycle; omitir la llamada al padre deja listeners colgados y provoca memory leaks.

## ¿Por qué es importante?

- **Liberación de recursos**: `ChangeNotifier` elimina listeners y callbacks en `super.dispose()`.
- **Memoria controlada**: Evita timers activos o controllers sin liberar cuando la pantalla se destruye.
- **Consistencia arquitectónica**: Alinea UiState con ViewModels, que ya cuentan con la regla `viewmodels_call_super_dispose`.
- **Testabilidad**: Reduce flakiness en tests que dependen del estado del UiState.

## Ejemplos

### ✅ Código correcto

```dart
class SearchUiState extends ChangeNotifier {
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose(); // ✅ Limpieza completa
  }
}

class FilterUiState extends BaseUiState {
  @override
  void dispose() {
    _filterTimer?.cancel();
    super.dispose(); // ✅ Llama al padre aunque esté en clase base
  }
}
```

### ❌ Código incorrecto

```dart
class SearchUiState extends ChangeNotifier {
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    // ❌ Falta super.dispose(), ChangeNotifier mantiene listeners vivos
  }
}

class DetailUiState extends BaseUiState {
  @override
  void dispose() {
    _subscription.cancel();
    if (mounted) {
      notifyListeners();
    }
    // ❌ Falta super.dispose(); incluso dentro de control de flujo
  }
}
```

## Cobertura de la regla

- Aplica a clases cuyo nombre termina en `UiState` o que extienden una clase/mixin `*UiState`.
- Analiza métodos `dispose()` concretos (no abstractos).
- Comprueba control de flujo: detecta `super.dispose()` dentro de bloques `if`, `try/finally`, etc.
- Ignora clases donde la jerarquía no expone un `dispose()` en el supertipo (evita falsos positivos en clases sin lifecycle).

## Testing guide

1. Crear un proyecto sandbox o reutilizar un proyecto consumidor existente.
2. Copiar `analysis_options.yaml.template` y habilitar `uistate_must_call_super_dispose` con nivel `error`.
3. Añadir casos en un archivo temporal:
   - Un `UiState` correcto que llame a `super.dispose()`.
   - Un `UiState` incorrecto sin la llamada; ejecutar `dart run custom_lint` y verificar que se emite el diagnóstico.
4. Opcional: validar interacciones con la regla `viewmodels_call_super_dispose` para asegurar mensajes diferenciados.

## Excepciones conocidas

- UiState que delegan totalmente en una clase base y no sobrescriben `dispose()` no se ven afectados.
- Si un UiState no hereda de `ChangeNotifier` (patrón no recomendado), la regla no se activa.

## Recursos


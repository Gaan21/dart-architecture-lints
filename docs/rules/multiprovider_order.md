# multiprovider_order

**Nivel**: ALTA | **Tipo**: Architecture | **Área**: Provider Composition

## Descripción

Verifica que dentro de un `MultiProvider` las instancias de `UiState` se declaren antes que los `ViewModel`. El patrón Provider Scoped UiState depende de que los ViewModels puedan leer el UiState durante `initialize()`; si el orden es incorrecto, las dependencias no existen en el árbol en el momento adecuado.

## ¿Por qué es importante?

- **Inicialización segura**: `ExpedienteListViewModel.initialize()` (y similares) leen `SearchUiState` en el primer frame (the project architecture guidelines).
- **Evita dependencias circulares**: Garantiza que el UiState esté disponible cuando el ViewModel se resuelva.
- **Consistencia del patrón**: Refuerza el flujo oficial Stateless → MultiProvider → UiState → ViewModel descrito en `02B_UI_PATTERNS.md`.

## Ejemplos

### ✅ Código correcto

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SearchUiState()),
    ChangeNotifierProvider(create: (_) => FilterUiState()),
    ChangeNotifierProvider(create: (_) => di<MyViewModel>()),
  ],
  child: const ScreenContent(),
);
```

### ❌ Código incorrecto

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => di<MyViewModel>()),
    ChangeNotifierProvider(create: (_) => SearchUiState()),
  ],
  child: const ScreenContent(),
);
// ❌ El ViewModel se registra antes del UiState
```

El lint ignora listas que usan spreads (`...commonProviders`) o helpers externos, de modo que no introduce falsos positivos cuando no puede determinar el orden real.

## Cobertura de la regla

- Solo analiza listas literales sin spreads para evitar ruido.
- Identifica tipos mediante el primer argumento genérico o el retorno del `create`.
- Clasifica proveedores como `UiState` o `ViewModel` cuando el nombre de la clase termina con dichos sufijos.
- Reporta el primer UiState que aparece después de un ViewModel en la lista.

## Testing guide

1. Copiar el snippet de `analysis_options.yaml.template` y habilitar `multiprovider_order` como `warning`.
2. Crear un widget temporal con distintos `MultiProvider`:
   - Variante válida con UiState antes de ViewModel.
   - Variante inválida con ViewModel primero (debe emitar warning).
   - Variante con spreads (`providers: [...coreProviders, ...featureProviders]`) que no debería reportar nada.
3. Ejecutar `dart run custom_lint` y comprobar que solo se reportan los casos esperados.

## Excepciones conocidas

- Listas construidas dinámicamente (`providers: buildProviders()`) quedan fuera del alcance; la guideline seguirá cubriendo estos casos vía code review.
- `ChangeNotifierProxyProvider` y proveedores que no retornan `UiState/ViewModel` explícitamente se ignoran.

## Recursos


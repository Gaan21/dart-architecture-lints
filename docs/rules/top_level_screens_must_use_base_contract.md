<!-- example-scope: isolated top_level_screens_must_use_base_contract -->

> **Example contract: `top_level_screens_must_use_base_contract` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# top_level_screens_must_use_base_contract

**Severidad**: `warning`
**Capa**: `presentation/screens/` (excluye `screens/base/`)

## Objetivo

Garantizar que todas las pantallas de nivel superior (`*Screen`) extiendan un contrato base definido en `screens/base/`, lo que permite compartir comportamiento transversal: analytics, theming, lifecycle hooks, etc.

## Cuándo aplica

La regla **solo está activa** cuando existe al menos un archivo `.dart` en un directorio `screens/base/` del proyecto. Si el proyecto aún no tiene contratos base, la regla no reporta nada (evita falsos positivos en repos sin este patrón).

## Detección

Analiza clases en `presentation/screens/**` que:

- Terminan en `Screen`
- No son abstractas
- No son privadas (`_Foo`)
- No están en la lista de excepciones hard-coded

Y verifica que su `extends` clause apunte a una clase con nombre `Base*Screen`.

### Excepciones hard-coded

Pantallas con responsabilidades especiales de bootstrapping que no se benefician del contrato base:

- `SplashScreen`
- `LockScreen`
- `AuthScreen`
- `MainShellScreen`

## Ejemplos

### ❌ MAL — pantalla sin contrato base

```dart
// lib/presentation/screens/profile/profile_screen.dart
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ProfileContent();
}
```

**Warning**: `top_level_screens_must_use_base_contract`

### ✅ BIEN — pantalla extiende contrato base

```dart
// lib/presentation/screens/base/base_authenticated_screen.dart
abstract class BaseAuthenticatedScreen extends StatelessWidget {
  const BaseAuthenticatedScreen({super.key});

  // Hooks compartidos: analytics, auth check, theming...
}

// lib/presentation/screens/profile/profile_screen.dart
class ProfileScreen extends BaseAuthenticatedScreen {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ProfileContent();
}
```

### ✅ BIEN — clase abstracta intermedia (no se reporta)

```dart
// No se reporta porque es abstract
abstract class BasePaymentScreen extends BaseAuthenticatedScreen {
  const BasePaymentScreen({super.key});
}
```

### ✅ BIEN — excepción hard-coded

```dart
// SplashScreen está en la lista de excepciones → no se reporta
class SplashScreen extends StatelessWidget { ... }
```

## Cómo crear un contrato base

```dart
// lib/presentation/screens/base/base_authenticated_screen.dart

/// Contrato base para pantallas que requieren usuario autenticado.
///
/// Proporciona:
/// - Verificación de autenticación en didChangeDependencies
/// - Track de pantalla en analytics
/// - Theming consistente
abstract class BaseAuthenticatedScreen extends StatelessWidget {
  const BaseAuthenticatedScreen({super.key});

  /// Override para personalizar el nombre de la pantalla en analytics.
  String get screenName => runtimeType.toString();
}
```

## Testing guide

### Setup en proyecto consumidor

1. Crear `lib/presentation/screens/base/base_app_screen.dart`:

```dart
abstract class BaseAppScreen extends StatelessWidget {
  const BaseAppScreen({super.key});
}
```

2. Crear pantalla sin base (debe reportar warning):

```dart
// lib/presentation/screens/home/home_screen.dart
class HomeScreen extends StatelessWidget { ... } // ← warning aquí
```

3. Crear pantalla con base (no debe reportar):

```dart
// lib/presentation/screens/home/home_screen.dart
class HomeScreen extends BaseAppScreen { ... } // ← sin warning
```

4. Ejecutar:

```bash
dart run custom_lint
```

### Verificar

- [ ] `HomeScreen extends StatelessWidget` → warning reportado
- [ ] `HomeScreen extends BaseAppScreen` → sin warning
- [ ] `SplashScreen extends StatelessWidget` → sin warning (excepción)
- [ ] `abstract class BaseHomeScreen extends StatelessWidget` → sin warning (es abstracta)
- [ ] Sin carpeta `screens/base/` → sin warnings (regla inactiva)

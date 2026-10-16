<!-- example-scope: isolated no_raw_exception_message_to_user -->

> **Example contract: `no_raw_exception_message_to_user` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_raw_exception_message_to_user

**Severidad**: `warning`
**Capa**: `presentation/`

## Objetivo

Impedir que mensajes crudos de excepción (`.message`, `.toString()`) lleguen directamente a componentes UI de notificación al usuario.

Los mensajes de error mostrados al usuario deben provenir de **códigos i18n estables**, no de strings de excepción que:
- Pueden cambiar entre versiones
- Pueden contener detalles internos (stack traces, queries SQL, rutas de servidor)
- No son localizables

## Detección

La regla analiza argumentos de los siguientes widgets/funciones en archivos de la capa `presentation/`:

**Widgets Flutter**: `Text`, `SelectableText`, `SnackBar`, `AlertDialog`, `SimpleDialog`, `Tooltip`

**Helpers de proyecto**: `showSnackbar`, `ShowSnackbar`, `showError`, `showWarning`, `showMessage`, `showInfo`, `showAlert`, `showDialog`, `showToast`, `showNotification`

Dentro de sus argumentos detecta:
- `error.message` / `exception.message` / `e.message`
- `error.toString()` / `exception.toString()`
- Interpolaciones: `'Error: ${error.message}'`

**Variables consideradas como excepción**: `error`, `err`, `e`, `exception`, `ex`, `failure`, o cualquier variable cuyo nombre termine en `Exception`, `Error`, `Failure`, `AppException`.

## Ejemplos

### ❌ MAL — mensaje crudo en Text

```dart
// lib/presentation/screens/profile/profile_screen.dart
Consumer<ProfileViewModel>(
  builder: (_, vm, __) {
    if (vm.uiState is UiStateError) {
      final error = (vm.uiState as UiStateError).error;
      return Text(error.message);  // ← warning aquí
    }
    return const ProfileContent();
  },
)
```

### ❌ MAL — toString() en SnackBar

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(exception.toString())),  // ← warning aquí
);
```

### ❌ MAL — interpolación en helper

```dart
showError('Ha ocurrido un error: ${error.message}');  // ← warning aquí
```

### ✅ BIEN — código i18n estable

```dart
Consumer<ProfileViewModel>(
  builder: (_, vm, __) {
    if (vm.uiState is UiStateError<AppException>) {
      final error = (vm.uiState as UiStateError<AppException>).error;
      final message = context.l10n.errorMessageFor(error.code);
      return Text(message);
    }
    return const ProfileContent();
  },
)
```

### ✅ BIEN — mensaje localizado en SnackBar

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(AppLocalizations.of(context)!.genericErrorMessage),
  ),
);
```

### ✅ BIEN — helper con código estable

```dart
showError(context.l10n.errorFor(error.code));
```

## Testing guide

### Setup en proyecto consumidor

Crea un archivo en `lib/presentation/screens/`:

```dart
// test_screen.dart
class TestScreen extends StatelessWidget {
  final AppException error;
  const TestScreen({required this.error, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ❌ Debe reportar warning:
        Text(error.message),
        // ❌ Debe reportar warning:
        Text(error.toString()),
        // ✅ No debe reportar:
        Text(context.l10n.errorFor(error.code)),
      ],
    );
  }
}
```

Ejecutar:

```bash
dart run custom_lint
```

### Verificar

- [ ] `Text(error.message)` → warning
- [ ] `Text(exception.toString())` → warning
- [ ] `SnackBar(content: Text(e.message))` → warning
- [ ] `showError('${error.message}')` → warning (interpolación)
- [ ] `Text(context.l10n.error(error.code))` → sin warning
- [ ] Mismo código fuera de `presentation/` → sin warning (scope)

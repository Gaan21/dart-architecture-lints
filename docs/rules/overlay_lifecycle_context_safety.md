# overlay_lifecycle_context_safety

**Rule name**: `overlay_lifecycle_context_safety`
**Severity**: `info` by default (configurable in `analysis_options.yaml`)
**Implementation**: AST + element resolution (not textual)
**Scope**: Flutter presentation code with dialogs, bottom sheets, pickers and routes

---

## Overview

Detecta dos anti-patrones de overlays que pueden provocar crashes de runtime:

1. Controllers/resources con lifecycle creados en el método llamante y capturados por `showDialog` / `showModalBottomSheet`.
2. Lookups de inherited widgets dentro del `builder` del overlay usando el `BuildContext` externo del caller.

El segundo caso no lo cubre `use_build_context_synchronously`: no hay necesariamente un `await` antes del uso del context. El context se captura y el framework puede re-ejecutar el builder del overlay más tarde, cuando el widget original ya está deactivated. El mensaje exacto en runtime (*"Looking up a deactivated widget's ancestor is unsafe"*) proviene de la assertion `_debugCheckStateIsActiveForAncestorLookup` del framework (`framework.dart`).

## Implementation (AST)

La regla resuelve el AST con elementos y **solo inspecciona el cuerpo del closure `builder:`** de cada overlay. Por eso los `build(BuildContext context)` normales del resto del fichero nunca se analizan (no hay falsos positivos por lookups fuera de overlays).

Overlays cubiertos:
- Funciones: `showDialog`, `showModalBottomSheet`, `showGeneralDialog`, `showCupertinoDialog`, `showCupertinoModalPopup`, `showDatePicker`, `showTimePicker`.
- Constructores de ruta (`addInstanceCreationExpression`): `MaterialPageRoute`, `CupertinoPageRoute`, `PageRouteBuilder`, `DialogRoute`, `RawDialogRoute`, `ModalBottomSheetRoute`, `CupertinoModalPopupRoute`.

Para cada overlay con argumento `builder` (un `FunctionExpression`):

1. **Caso A** — se recogen las declaraciones de variables **locales** (no campos de State) de tipo `TextEditingController`, `FocusNode`, `AnimationController`, `ScrollController`, `PageController` o `TabController` en el cuerpo que abre el overlay, excluyendo las declaradas dentro del builder. Si el elemento de alguna se **referencia dentro del builder**, se marca en su declaración. Comparación por identidad de elemento; los campos de State no son `VariableDeclaration` locales, así que nunca se marcan.
2. **Caso B** — dentro del builder, para cada lookup heredado (`Theme.of(ctx)`, `AppLocalizations.of(ctx)`, `MediaQuery.*Of(ctx)`, `Provider.of(ctx)`, `Navigator/GoRouter/Localizations/…`, o `ctx.read/watch/select<T>()` con `ctx` de tipo `BuildContext`), se comprueba si el elemento del `context` usado está **declarado dentro del closure** (parámetro propio del builder o de un `Builder` anidado). Si NO lo está (capturado del caller), se marca el lookup.

Limitaciones conocidas:
- Si `builder:` es una referencia a método (no un closure literal), no se analiza.
- No intenta probar si el context externo sigue montado; prohíbe el patrón por diseño (usar el context del builder o resolver antes de abrir el overlay).

## BAD — controller local capturado

```dart
Future<void> reject(BuildContext context) async {
  final controller = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await save(controller.text.trim());
  }
  controller.dispose();
}
```

## GOOD — controller owned by overlay widget

```dart
Future<String?> askReason(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _ReasonDialog(),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
```

## BAD — inherited lookup with caller context

```dart
Future<void> showDetails(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => Text(
      AppLocalizations.of(context)?.detailsTitle ?? '',
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
}
```

## GOOD — resolve values before opening overlay

```dart
Future<void> showDetails(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final router = GoRouter.of(context);

  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _DetailsSheet(
      title: l10n?.detailsTitle ?? '',
      onOpen: () => router.pushNamed('details'),
    ),
  );
}
```

## GOOD — use overlay builder context

```dart
Future<void> showDetails(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => Text(
      AppLocalizations.of(sheetContext)?.detailsTitle ?? '',
      style: Theme.of(sheetContext).textTheme.titleMedium,
    ),
  );
}
```

## Tests

Unit tests (resolved-AST fixtures): `test/overlay_lifecycle_context_safety_test.dart`.
Cubren positivos A/B (incluyendo `MaterialPageRoute`) y los falsos positivos que una implementación textual produce:

- controller como **campo de State** usado en el builder → no se marca;
- builder que usa **su propio** parámetro `context` → no se marca;
- `build(BuildContext context)` normal con `Theme.of(context)` → no se marca;
- `Builder` anidado usando su `ctx` interno → no se marca;
- controller declarado **dentro** del builder → no se marca;
- `showTimePicker` cuyo builder usa su propio `ctx` → no se marca.

```bash
dart test test/overlay_lifecycle_context_safety_test.dart
```

### Validación contra app real

Probada contra el repositorio WorkTracker mediante `dependency_overrides` (path local) + `dart run custom_lint`, sin commitear: pasó de los falsos positivos de la versión textual (128 marcas en 20 ficheros, incluyendo `build` normales y código ya correcto) a **1 único verdadero positivo** (patrón A). Tras corregir ese caso, el barrido queda en **0**.

<!-- example-scope: isolated no_utc_time_format_without_empresa_helper -->

> **Example contract: `no_utc_time_format_without_empresa_helper` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_utc_time_format_without_empresa_helper

**Severity**: warning  
**Category**: timezone-safety

## What it detects

`DateFormat` calls using a **time pattern** (hours/minutes) where the argument
has not been converted through an approved empresa time helper before formatting.

### Root cause (real bug)

```
Trabajador crea incidencia → ve 17:00 / 20:00  ✅ (hora empresa)
Admin abre bottomsheet    → ve 15:00 / 18:00  ❌ (hora UTC)
```

The admin view called `DateFormat('HH:mm').format(timestampUtc)` directly
instead of first converting the UTC instant to empresa local time.

## Examples

### ❌ Violación — formateo UTC sin conversión

```dart
// lib/presentation/incident_bottomsheet.dart
String formatHour(DateTime timestampUtc) {
  // Displays UTC hour — admin sees wrong time!
  return DateFormat('HH:mm').format(timestampUtc);
}
```

```dart
// lib/widgets/schedule_row.dart
String render(IncidentModel model) {
  final f = DateFormat('HH:mm:ss');
  return f.format(model.timestampPropuestoDateTime); // raw UTC
}
```

```dart
// lib/screens/time_picker.dart
String display(DateTime ts) => DateFormat.Hm().format(ts); // named constructor
```

### ✅ Correcto — con helper de empresa

```dart
// lib/presentation/incident_bottomsheet.dart
String formatHour(EmpresaTimeService svc, DateTime timestampUtc) {
  return DateFormat('HH:mm').format(
    svc.toEmpresaLocalTime(timestampUtc),
  );
}
```

```dart
// lib/widgets/range_chip.dart
String chip(DateTime dt) {
  return DateFormat('HH:mm').format(
    EmpresaDateTimeFormatter.formatCivilDate(dt),
  );
}
```

### ✅ No se detecta — formato de fecha civil (sin hora)

```dart
// lib/presentation/date_label.dart
String label(DateTime fechaCivil) {
  return DateFormat('dd/MM/yyyy').format(fechaCivil); // no hour letter
}
```

## Configuration

```yaml
custom_lint:
  rules:
    - no_utc_time_format_without_empresa_helper:
        include_globs:
          - "**/presentation/**"
          - "**/screens/**"
          - "**/widgets/**"
          - "**/ui/**"
        exclude_globs:
          - "**/test/**"
          - "**/tests/**"
          - "**/*_test.dart"
        allowed_wrappers:
          - "*.toEmpresaLocalTime"
          - "EmpresaDateTimeFormatter.*"
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `include_globs` | `List<String>` | `**/presentation/**`, `**/screens/**`, `**/widgets/**`, `**/ui/**` | Paths where the rule is active |
| `exclude_globs` | `List<String>` | `**/test/**`, `**/tests/**`, `**/*_test.dart` | Paths always skipped |
| `allowed_wrappers` | `List<String>` | `*.toEmpresaLocalTime`, `EmpresaDateTimeFormatter.*` | Wildcard patterns for approved wrappers. The argument to `.format()` must be a direct call matching one of these. |

## Detection logic

The rule reports when ALL three conditions hold:

1. **Method is `.format(...)`** — the call is on any object.
2. **Target is a time-format DateFormat** — detected via:
   - `DateFormat('HH:mm')` — string arg containing ICU hour letters `H h k K j J`
   - `DateFormat.Hm()` / `DateFormat.jm()` / `DateFormat.Hms()` etc. (named constructors)
   - Identifier whose name contains time-signal words: `time`, `hour`, `hora`, `hm`, `hms`, `minute`, `clock`
3. **Argument is NOT an approved wrapper call** — the direct argument to `.format()` must be a method invocation matching one of the `allowed_wrappers` patterns.

## Known limitations

| Scenario | Handled? | Notes |
|----------|----------|-------|
| `DateFormat('HH:mm').format(raw)` | ✅ | Direct — always detected |
| `DateFormat.Hm().format(raw)` | ✅ | Named constructor — always detected |
| `timeFormatter.format(raw)` | ✅ | Name heuristic matches `time` word |
| `final f = DateFormat('HH:mm'); f.format(raw)` | ⚠️ | Only if `f` has a time-signal name |
| Date-only patterns (`dd/MM/yyyy`) | ✅ | Skipped — no hour ICU letter |
| Test files | ✅ | Excluded by default |
| Generated files (`.g.dart`, `.freezed.dart`) | ✅ | Skipped by base class |

**Variable aliases without time-signal names** (`final f = …; f.format(raw)`) are
a known gap — use naming conventions (`hourFormatter`, `timeFormat`) to help the
rule detect them, or use direct calls.

## Testing guide

In your consumer project (`work_tracker`):

```bash
cd /path/to/work_tracker
dart run custom_lint
```

Expect to see errors like:
```
warning - lib/presentation/incidents/incident_tile.dart:42:5 -
  DateFormat time-pattern used without an approved empresa time helper. ...
  no_utc_time_format_without_empresa_helper
```

Fix by wrapping with `empresaTimeService.toEmpresaLocalTime(...)`:

```dart
// Before (flagged)
DateFormat('HH:mm').format(model.timestampPropuesto)

// After (approved)
DateFormat('HH:mm').format(
  empresaTimeService.toEmpresaLocalTime(model.timestampPropuesto),
)
```

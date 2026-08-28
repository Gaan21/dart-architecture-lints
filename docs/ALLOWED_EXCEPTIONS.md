# Excepciones Permitidas - Custom Lint Rules

> Este documento lista las excepciones **documentadas y justificadas** para las reglas custom lint. Estas excepciones existen por diseño arquitectónico, limitaciones técnicas, o casos de uso legítimos que no deben ser flaggeados.

**Importante**: Las excepciones deben ser **minimizadas** y **justificadas**. Solo añadir nuevas excepciones tras análisis cuidadoso.

---

## 📋 Índice de Reglas con Excepciones

1. [no_late_keyword](#no_late_keyword)
2. [no_bang_operator](#no_bang_operator)
3. [enforce_final_variables](#enforce_final_variables)
4. [viewmodels_no_flutter_types](#viewmodels_no_flutter_types)
5. [viewmodels_no_buildcontext](#viewmodels_no_buildcontext)
6. [avoid_hardcoded_strings](#avoid_hardcoded_strings)
7. [usecases_follow_pattern](#usecases_follow_pattern)
8. [check_context_mounted](#check_context_mounted)

---

## Reglas con Excepciones Documentadas

### `no_late_keyword`

**Regla**: Prohibir `late` keyword excepto para casos justificados de dependency injection.

#### ✅ PERMITIDO: `late final` para Dependency Injection

**Excepción**: Campos `late final` con tipos relacionados a DI frameworks.

**Tipos permitidos**:
- `GetIt`, `Locator`, `ServiceLocator`
- `Container`, `Injector`, `Provider`, `Resolver`
- Clases en archivos que contienen `container`, `locator`, `di` en su nombre

**Razón**:
- DI frameworks requieren inicialización lazy controlada
- Usar nullable (`Type?`) rompe el contrato de "siempre disponible" del servicio
- Inicializar en constructor no es posible para singletons globales

**Ejemplo permitido**:
```dart
class ServiceContainer {
  late final GetIt locator;

  void init() {
    locator = GetIt.instance;
  }
}
```

**NO permitido**:
```dart
// ❌ 'late' sin 'final'
late String userName;

// ❌ 'late' para lógica de negocio
late final String computedValue;
```

---

### `no_bang_operator`

**Regla**: Evitar operador `!` (null assertion) para prevenir crashes en runtime.

#### ✅ PERMITIDO: Map/List lookups garantizados por diseño

**Excepción**: Accesos a Maps/Lists donde la key/index está **garantizado** que existe por diseño del sistema.

**Criterios**:
- Key recién insertada en el mismo scope
- Index verificado explícitamente antes de acceso
- Constantes del sistema que siempre existen

**Ejemplo permitido**:
```dart
// ✅ Key recién insertada
final cache = <String, User>{};
cache['user_123'] = currentUser;
final user = cache['user_123']!; // OK: acabamos de insertar

// ✅ Index verificado
if (list.length > index) {
  final item = list[index]!; // OK si tipo es List<T?>
}
```

**NO permitido**:
```dart
// ❌ Asunción sin garantía
final user = userCache[userId]!; // Puede no existir

// ❌ API externa
final data = json['field']!; // JSON puede no tener campo
```

**Recomendación**: Si encuentras muchos casos donde necesitas `!`, considera refactorizar para usar tipos non-nullable desde el origen.

---

### `enforce_final_variables`

**Regla**: Preferir `final` sobre `var` para inmutabilidad.

#### ✅ PERMITIDO: Variables que SÍ se reasignan

**Excepción**: Variables que **deben** ser reasignadas múltiples veces (acumuladores, contadores, loops).

**Casos permitidos**:
- **For loops tradicionales**: `for (var i = 0; i < n; i++)`
- **Acumuladores**: Variables que acumulan valores en un loop
- **State machines**: Variables que cambian de estado explícitamente
- **Parsers**: Variables que mutan durante procesamiento secuencial

**Ejemplo permitido**:
```dart
// ✅ For loop tradicional
for (var i = 0; i < items.length; i++) {
  print(items[i]);
}

// ✅ Acumulador
var total = 0;
for (final item in items) {
  total += item.price;
}

// ✅ State machine
var currentState = State.initial;
while (!done) {
  currentState = processState(currentState);
}
```

**NO permitido**:
```dart
// ❌ Variable asignada una sola vez
var userName = "John"; // Usar final

// ❌ Variable que no se reasigna en loop
for (final item in items) {
  var processedItem = item.transform(); // Usar final
  print(processedItem);
}
```

---

### `viewmodels_no_flutter_types`

**Regla**: ViewModels no deben contener tipos Flutter (`BuildContext`, `GlobalKey<FormState>`, etc.) para mantener testabilidad.

#### ✅ PERMITIDO: `GlobalKey<NavigatorState>` en navigation ViewModels

**Excepción**: `GlobalKey<NavigatorState>` se permite **específicamente** en ViewModels que gestionan navegación global (tabs, drawer, deep linking).

**Razón**:
- La navegación global requiere acceso a `NavigatorState` a través de GlobalKey
- Crear un `NavigationUiState` separado añade complejidad innecesaria (fragmentación)
- El acoplamiento a Flutter es inevitable para navegación programática
- No hay alternativa oficial de Flutter que sea UI-agnostic

**Ejemplo permitido**:
```dart
class TabNavigationViewModel extends BaseViewModel {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void navigateToTab(int index) {
    navigatorKey.currentState?.pushNamed(routes[index]);
  }

  void popToRoot() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
}
```

**Uso en proyecto**: `lib/presentation/viewModels/tab_navigation_view_model.dart:15-55`

**Importante**:
- ❌ Otros `GlobalKey` types (ej: `GlobalKey<FormState>`, `GlobalKey<ScaffoldState>`) NO están permitidos
- ✅ Deben moverse a UiState para mantener separación de concerns

**Alternativa evaluada y rechazada**:
```dart
// ❌ NO: Fragmentación innecesaria
class NavigationUiState extends ChangeNotifier {
  final navigatorKey = GlobalKey<NavigatorState>();
}

class TabNavigationViewModel {
  final NavigationUiState _navState; // Acoplamiento adicional
}
```

---

### `viewmodels_no_buildcontext`

**Regla**: ViewModels no deben recibir ni almacenar `BuildContext`.

#### ⚠️ NO HAY EXCEPCIONES - Usar effects/events

**Posición**: Esta regla **NO tiene excepciones permitidas**.

**Si necesitas comunicación ViewModel → Widget**:
- ✅ Usa **effects/events** que el Widget escucha
- ✅ Usa **callbacks** inyectados en constructor
- ✅ Usa **state properties** que el Widget observa

**Patrón recomendado (effects)**:
```dart
// ViewModel
class DetailViewModel extends BaseViewModel {
  void saveItem() async {
    final result = await repository.save(item);
    if (result.isSuccess) {
      // ✅ Emitir effect en lugar de Navigator.pop(context)
      emitEffect(NavigateBackEffect());
    }
  }
}

// Widget
BlocListener<DetailViewModel, DetailState>(
  listener: (context, state) {
    if (state.effect is NavigateBackEffect) {
      Navigator.pop(context);
    }
  },
  child: /* ... */,
)
```

**Por qué NO permitimos excepciones**:
- Rompe testabilidad (tests requieren mock de BuildContext)
- Acopla lógica de negocio a UI
- Previene reutilización del ViewModel en diferentes plataformas

---

### `avoid_hardcoded_strings`

**Regla**: Detectar strings UI sin internacionalización.

#### ✅ PERMITIDO: Strings técnicos (no UI)

**Excepción**: Strings que **NO son texto visible** para el usuario.

**Casos permitidos**:
- **Keys**: Map keys, SharedPreferences keys, API keys
- **Debug logs**: `print()`, `debugPrint()`, `logger.debug()`
- **Constantes técnicas**: URLs, rutas, regex patterns
- **Test strings**: Strings en archivos `*_test.dart`
- **Asset paths**: Rutas de imágenes, fuentes, archivos

**Ejemplo permitido**:
```dart
// ✅ Keys (no UI)
const userIdKey = 'user_id';
prefs.getString(userIdKey);

// ✅ Debug logging
debugPrint('User logged in successfully');

// ✅ Constantes técnicas
const apiBaseUrl = 'https://api.example.com';
const emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';

// ✅ Asset paths
Image.asset('assets/images/logo.png')
```

**NO permitido**:
```dart
// ❌ Texto visible al usuario
Text('Welcome to the app'); // Usar i18n

// ❌ Mensajes de error UI
showDialog(message: 'Invalid email'); // Usar i18n

// ❌ Labels de botones
ElevatedButton(
  child: Text('Save'), // Usar i18n
  onPressed: onSave,
)
```

**Nota**: Si dudas si un string debe internacionalizarse, pregúntate: *"¿Un usuario de otro país necesitaría ver esto en su idioma?"*

---

### `usecases_follow_pattern`

**Regla**: UseCases deben tener método `execute()` que retorna `Result<T>`.

#### ✅ PERMITIDO: Factory methods y helpers privados

**Excepción**: Métodos adicionales que **NO son el entry point** del UseCase.

**Casos permitidos**:
- **Factory methods**: `static` constructors o builders
- **Helpers privados**: Métodos `_private` de descomposición
- **Validators**: Métodos de validación que retornan `bool` o `ValidationResult`

**Ejemplo permitido**:
```dart
class CreateUserUseCase {
  // ✅ Entry point principal (obligatorio)
  Future<Result<User>> execute(CreateUserParams params) async {
    if (!_validateParams(params)) {
      return Result.failure(ValidationError());
    }

    final user = _buildUser(params);
    return await repository.create(user);
  }

  // ✅ Helper privado (permitido)
  bool _validateParams(CreateUserParams params) {
    return params.email.isNotEmpty && params.age > 0;
  }

  // ✅ Factory method (permitido)
  User _buildUser(CreateUserParams params) {
    return User(
      email: params.email,
      age: params.age,
    );
  }
}
```

**NO permitido**:
```dart
class CreateUserUseCase {
  // ❌ Método público que no retorna Result<T>
  Future<User> createUser(String email) async { // Usar execute()
    return repository.create(User(email: email));
  }

  // ❌ Múltiples entry points públicos
  Future<Result<User>> createActive() { /* ... */ }
  Future<Result<User>> createInactive() { /* ... */ }
  // Mejor: Un solo execute() con parámetro 'isActive'
}
```

---

### `check_context_mounted`

**Regla**: Verificar `context.mounted` después de operaciones async antes de usar `BuildContext`.

#### ✅ PERMITIDO: Métodos síncronos del lifecycle

**Excepción**: Métodos del lifecycle que **NO contienen** operaciones async (`initState`, `dispose`, `build`).

**Razón**:
- Estos métodos son síncronos por diseño de Flutter
- `context.mounted` es siempre `true` durante su ejecución
- No hay riesgo de uso tras dispose

**Ejemplo permitido**:
```dart
@override
void initState() {
  super.initState();
  // ✅ OK: initState es síncrono, context siempre mounted
  context.read<ViewModel>().loadInitialData();
}

@override
Widget build(BuildContext context) {
  // ✅ OK: build es síncrono, context siempre mounted
  final viewModel = context.watch<ViewModel>();
  return Text(viewModel.data);
}

@override
void dispose() {
  // ✅ OK: dispose es síncrono
  context.read<ViewModel>().cleanup();
  super.dispose();
}
```

**NO permitido** (requiere mounted check):
```dart
Future<void> loadData() async {
  await repository.fetchData(); // async operation

  // ❌ DEBE verificar mounted antes de usar context
  if (!context.mounted) return;

  context.read<ViewModel>().updateData(data);
}

void setupTimer() {
  Timer(Duration(seconds: 5), () {
    // ❌ DEBE verificar mounted (callback asíncrono)
    if (!context.mounted) return;

    setState(() => counter++);
  });
}
```

---

## 🔧 Cómo Documentar Nuevas Excepciones

**Proceso** (requiere aprobación en PR review):

1. **Identificar necesidad real**: ¿Es una violación legítima por diseño?
2. **Evaluar alternativas**: ¿Hay forma de evitar la excepción refactorizando?
3. **Documentar aquí**:
   ```markdown
   ### `nombre_regla`

   #### ✅ PERMITIDO: Descripción breve

   **Excepción**: Qué se permite y por qué

   **Razón**:
   - Punto 1
   - Punto 2

   **Ejemplo permitido**:
   ```dart
   // código ejemplo
   ```

   **NO permitido**:
   ```dart
   // contraejemplo
   ```
   ```

4. **Actualizar implementación**: Si es posible, modificar la regla para skipear el caso
5. **Actualizar tests**: Verificar que la excepción no genera false positive
6. **Notificar al equipo**: PR review + comunicación en Slack/Teams

---

## ⚠️ Principios para Excepciones

1. **Minimizar excepciones**: Cada excepción debilita la regla
2. **Justificar técnicamente**: No solo "es más fácil así"
3. **Documentar ejemplos**: Código real, no abstracto
4. **Actualizar regla si posible**: Hacer que el lint detecte la excepción automáticamente
5. **Revisar periódicamente**: ¿La excepción sigue siendo necesaria?

**Pregunta clave**: *"¿Esta excepción mejora la arquitectura o solo evita trabajo?"*

---

**Última actualización**: 2025-10-06
**Responsable**: Equipo de arquitectura
**Revisión**: Cada 6 meses o al añadir nueva regla

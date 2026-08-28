# no_business_logic_in_widgets

**Severidad**: `warning`

## Descripción

Detecta lógica de negocio (filtrados complejos, instanciación de UseCases/Repositories, transformaciones de dominio) en Widgets. Enforza separación MVVM: **Widgets solo renderizan, ViewModels/UiState procesan**.

## Motivación

Colocar lógica de negocio en Widgets es un anti-patrón que:
- **Dificulta testing**: Widgets con lógica requieren integration tests (lentos), no unit tests
- **Reduce trazabilidad**: Lógica dispersa entre Widget y ViewModel
- **Rompe MVVM**: Widgets deben ser "dumb", solo renderizar datos ya procesados
- **Duplica código**: Misma lógica repetida en múltiples Widgets

**Referencias**:
- Guideline: `02B_UI_SCREENS_FAQ.md` - Anti-patrón documentado
- Patrón recomendado: ViewModel expone datos procesados, Widget solo renderiza

## Alcance

- **Archivos**: `lib/presentation/screens/` y `lib/presentation/widgets/`
- **Detecta** patrones de lógica de negocio en:
  - Métodos `build` de Widgets
  - `initState` de StatefulWidget
  - Callbacks `_on*` en Widgets

- **Patrones detectados**:
  1. Instanciación directa de UseCases/Repositories (`FooRepository()` en Widget)
  2. Filtrado/transformación compleja con `where`, `fold`, `map` + múltiples condiciones (>= 2 && o ||)
  3. Llamadas a `context.read<ViewModel>().useCase.execute()` o `vm.useCase.execute()` desde Widgets

- **Excluye** transformaciones simples:
  - `items.isEmpty`, `list.length`, `text.toUpperCase()`
  - Formateo de UI (`NumberFormat`, `DateFormat`)
  - Operadores simples sin múltiples condiciones

## Ejemplos

### ❌ Incorrecto - Filtrado complejo en Widget

```dart
// ❌ Filtrado con lógica de negocio en Widget
class _Content extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrdersViewModel>();
    final query = context.watch<SearchUiState>().query;

    // ❌ no_business_logic_in_widgets
    final filtered = vm.orders
        .where((order) => order.customer.contains(query) && order.isActive && !order.isPaid)
        .toList();

    return OrdersList(filtered);
  }
}
```

**Problema**: Lógica de negocio (qué órdenes mostrar) en Widget, no testeable con unit tests.

### ✅ Correcto - ViewModel expone datos procesados

```dart
// ✅ ViewModel expone datos listos para renderizar
class OrdersViewModel extends BaseViewModel<List<Order>> {
  String _query = '';

  List<Order> get filteredOrders => _orders
      .where((order) => _matchesQuery(order) && order.isActive && !order.isPaid)
      .toList();

  void updateQuery(String query) {
    _query = query;
    notifyListeners();
  }

  bool _matchesQuery(Order order) {
    return order.customer.toLowerCase().contains(_query.toLowerCase());
  }
}

// ✅ Widget solo renderiza
class _Content extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final filtered = context.select((OrdersViewModel vm) => vm.filteredOrders);
    return OrdersList(filtered);
  }
}
```

**Beneficios**:
- Lógica de negocio en ViewModel (testeable con unit tests)
- Widget "dumb" (solo renderiza)
- Reutilizable (otros Widgets pueden usar `filteredOrders`)

### ❌ Incorrecto - Instanciación directa de UseCase

```dart
// ❌ Instanciación de UseCase en Widget
class UserProfileWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ❌ no_business_logic_in_widgets
    final getUserUseCase = GetUserUseCase(
      context.read<UserRepository>(),
    );

    return FutureBuilder(
      future: getUserUseCase.execute(userId),
      builder: (context, snapshot) {
        // ...
      },
    );
  }
}
```

**Problema**: Widget conoce dependencias de negocio (UseCase, Repository), viola MVVM.

### ✅ Correcto - Dependencias inyectadas en ViewModel

```dart
// ✅ ViewModel con dependencias inyectadas
class UserProfileViewModel extends BaseViewModel<User> {
  final GetUserUseCase _getUserUseCase;

  UserProfileViewModel(this._getUserUseCase);

  Future<void> loadUser(String userId) async {
    setState(UiState.loading());
    final result = await _getUserUseCase.execute(userId);
    handleResult(result);
  }
}

// ✅ Widget solo renderiza
class UserProfileWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserProfileViewModel>();

    return vm.state.when(
      loading: () => CircularProgressIndicator(),
      data: (user) => UserCard(user),
      error: (error) => ErrorWidget(error),
    );
  }
}
```

### ❌ Incorrecto - Execute desde Widget

```dart
// ❌ Llamada directa a useCase.execute() desde Widget
class OrderButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final vm = context.read<OrdersViewModel>();
        // ❌ no_business_logic_in_widgets
        await vm.createOrderUseCase.execute(orderId);
      },
      child: Text('Create Order'),
    );
  }
}
```

**Problema**: Widget accede directamente a UseCase expuesto por ViewModel (violation de encapsulación).

### ✅ Correcto - Método del ViewModel

```dart
// ✅ ViewModel encapsula lógica
class OrdersViewModel extends BaseViewModel<List<Order>> {
  final CreateOrderUseCase _createOrderUseCase;

  OrdersViewModel(this._createOrderUseCase);

  Future<void> createOrder(String orderId) async {
    setState(UiState.loading());
    final result = await _createOrderUseCase.execute(orderId);
    handleResult(result);
  }
}

// ✅ Widget llama método del ViewModel
class OrderButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        context.read<OrdersViewModel>().createOrder(orderId);
      },
      child: Text('Create Order'),
    );
  }
}
```

### ✅ Correcto - Transformaciones simples permitidas

```dart
// ✅ Transformaciones simples NO son lógica de negocio
class UserList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final users = context.watch<UsersViewModel>().users;

    // ✅ OK: Validación simple
    if (users.isEmpty) {
      return Text('No users found');
    }

    // ✅ OK: Formateo UI
    final displayName = users.first.name.toUpperCase();

    // ✅ OK: Filtrado simple con 1-2 condiciones (permitido tras calibración)
    final activeUsers = users.where((u) => u.isActive && !u.isDeleted).toList();

    // ✅ OK: Map simple con formateo (< 80 caracteres)
    final names = users.map((u) => u.name.toUpperCase()).toList();

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) => UserCard(users[index]),
    );
  }
}
```

## Implementación Técnica

### Heurística AST

La regla detecta tres patrones principales:

**1. Instanciación directa de UseCases/Repositories**:
```dart
// Detecta: new FooUseCase(), FooRepository(), etc.
InstanceCreationExpression donde typeName termina en:
- "UseCase"
- "Repository"
- "RepositoryImpl"
```

**2. Filtrado/transformación compleja con múltiples condiciones**:
```dart
// Detecta: .where((x) => ...), .fold(0, (a, x) => ...), .map((x) => ...)
MethodInvocation donde:
- methodName == "where", "fold", o "map"
- Closure tiene >= 2 operadores (&&, ||)
- Closure length > 60 caracteres
- Nota: Para fold, verifica el segundo argumento (el closure)
```

**3. Execute directo desde Widget**:
```dart
// Detecta: vm.useCase.execute() o context.read<VM>().useCase.execute()
MethodInvocation donde:
- methodName == "execute"
- target es PropertyAccess (ej: context.read<VM>().useCase) O
- target es PrefixedIdentifier (ej: vm.useCase donde vm es variable local)
- propertyName termina en "UseCase" o "useCase"
```

### Falsos positivos estimados

**~15-25%** (reducido tras calibración) - Casos legítimos que pueden disparar warning:
- Transformaciones con closures largos pero simples (ej: map con formateo)
- Widgets con lógica UI compleja pero NO de negocio
- Instanciación de clases que terminan en "UseCase" pero NO son UseCases

**Estrategias de mitigación**:
1. **Refactorizar**: Mover lógica a ViewModel (recomendado)
2. **Ignore puntual**: `// ignore: no_business_logic_in_widgets` solo si justificado
3. **Calibrar heurísticas**: Ajustar thresholds (caracteres, condiciones) según proyecto

### Severidad: WARNING (no ERROR)

Esta regla usa `warning` porque:
- Falsos positivos ~20-30% requieren revisión humana (calibrado para detectar más casos)
- Heurísticas basadas en patrones, no análisis semántico completo
- Algunas transformaciones complejas pueden ser legítimas en Widgets

**Calibración aplicada**:
- Umbral de caracteres: 50 → 80 → **60 caracteres** (detecta closures moderadamente largos con lógica)
- Umbral de condiciones: 3 → **2 operadores** (alineado con guideline que marca 2 operadores como malo)

**Justificación del threshold 60/2**:
- La guideline oficial (`TODO_NEW_LINTER_RULES.md:554`) marca como **MALO** un ejemplo con solo 2 operadores `&&`
- Closures con 60+ caracteres Y 2+ operadores típicamente contienen lógica de negocio, no solo formateo UI
- Filtra casos triviales: `items.where((i) => i.active && i.visible)` (~45 chars) no se detecta
- Detecta casos problemáticos: `items.where((i) => i.customer.contains(q) && i.isActive && !i.isPaid)` (~70 chars)

**Considerar ERROR** si:
- Proyecto nuevo con MVVM estricto
- Falsos positivos < 10% tras observación en proyecto real
- Team acuerda enforcement severo

## Testing Guide

### En un proyecto consumidor separado

1. **Crear Widget con lógica de negocio**:
```dart
// lib/presentation/screens/test_screen.dart
class TestContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TestViewModel>();

    // ❌ Filtrado complejo
    final filtered = vm.items
        .where((item) => item.isActive && item.priority > 5 && !item.isDone)
        .toList();

    // ❌ Instanciación directa
    final useCase = GetDataUseCase(context.read<DataRepository>());

    return ListView(children: filtered.map((i) => Text(i.name)).toList());
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
warning • No mezcles lógica de negocio en Widgets; delega en ViewModel o UiState. Widgets solo deben renderizar datos ya procesados. • lib/presentation/screens/test_screen.dart:7:5 • no_business_logic_in_widgets
warning • No mezcles lógica de negocio en Widgets; delega en ViewModel o UiState. Widgets solo deben renderizar datos ya procesados. • lib/presentation/screens/test_screen.dart:11:19 • no_business_logic_in_widgets
```

4. **Corregir moviendo lógica a ViewModel**:
```dart
// ViewModel expone datos procesados
class TestViewModel extends BaseViewModel<List<Item>> {
  List<Item> get filteredItems => _items
      .where((item) => item.isActive && item.priority > 5 && !item.isDone)
      .toList();
}

// Widget solo renderiza
class TestContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final filtered = context.select((TestViewModel vm) => vm.filteredItems);
    return ListView(children: filtered.map((i) => Text(i.name)).toList());
  }
}
```

5. **Confirmar fix**:
```bash
dart run custom_lint
# Sin warnings de no_business_logic_in_widgets
```

## Complementariedad

Esta regla completa el enforcement de MVVM junto con:

1. ✅ `viewmodels_extend_base_viewmodel` - ViewModels con BaseViewModel
2. ✅ `viewmodels_no_buildcontext` - ViewModels sin BuildContext
3. ✅ `viewmodels_no_flutter_types` - ViewModels sin tipos Flutter
4. ✅ `screens_must_be_stateless` - Screens como StatelessWidget
5. ✅ `no_business_logic_in_widgets` (ESTA REGLA) - Widgets sin lógica de negocio

**Resultado combinado**: Separación estricta UI/Logic con Widgets "dumb" que solo renderizan.

## Notas de Implementación

### Limitaciones conocidas

Esta regla usa **heurísticas AST** (no análisis semántico completo), por lo que:

1. **No detecta**: Lógica de negocio sin patrones obvios
   ```dart
   // Puede NO detectarse (closure corto sin &&/||)
   final filtered = items.where((i) => i.id > 10).toList();
   ```

2. **Puede generar falsos positivos**: Closures largos pero legítimos
   ```dart
   // Puede flaggearse (closure largo con formateo UI)
   final formatted = items.map((i) =>
     '${i.name} - ${DateFormat.yMd().format(i.date)} - ${i.status}'
   ).toList();
   ```

3. **No analiza semántica**: Solo patrones sintácticos
   - No distingue "lógica de dominio" vs "lógica UI"
   - Se basa en nombres (UseCase, Repository) y estructura (where + &&)

### Mejoras futuras

Posibles mejoras para reducir falsos positivos:

1. **Análisis de tipos**: Detectar transformaciones sobre tipos de dominio (Entity, Model)
2. **Control-flow analysis**: Identificar decisiones de negocio (if/switch complejos)
3. **Thresholds configurables**: Permitir ajustar límites (caracteres, condiciones) por proyecto
4. **Whitelist**: Excluir ciertos métodos conocidos (formatters, validators simples)

## Referencias Técnicas

- **custom_lint API**: `ClassDeclaration`, `MethodDeclaration`, `MethodInvocation`, `InstanceCreationExpression`
- **AST Visitor**: `RecursiveAstVisitor` para detectar patrones anidados
- **Heurísticas**: Basadas en nombres, longitud de código, y conteo de operadores
- **Guidelines**: `02B_UI_SCREENS_FAQ.md` - Anti-patrones documentados

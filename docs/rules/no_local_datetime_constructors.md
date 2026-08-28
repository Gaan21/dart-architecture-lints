# no_local_datetime_constructors

## Descripción
Esta regla detecta el uso directo de `DateTime.now()` y sugiere el uso de inyección de dependencias con `Clock` para mejor testabilidad.

## ¿Por qué es importante?
- **Testabilidad**: `DateTime.now()` dificulta las pruebas unitarias
- **Inyección de dependencias**: Facilita el mocking del tiempo
- **Guidelines**: Cumple las invariantes del proyecto sobre reloj inyectable
- **Determinismo**: Permite controlar el tiempo en tests

## Detecta
```dart
// ❌ Casos que generan error
class UserService {
  User createUser() => User(
    createdAt: DateTime.now() // ❌ Uso directo
  );
}

final timestamp = DateTime.now(); // ❌ En cualquier contexto
```

## No detecta (casos permitidos)
```dart
// ✅ Clock inyectado
class UserService {
  final Clock _clock;
  UserService(this._clock);
  
  User createUser() => User(
    createdAt: _clock.now().toUtc() // ✅ Clock inyectado
  );
}

// ✅ En archivos de test
test('should work', () {
  final now = DateTime.now(); // ✅ Permitido en tests
});

// ✅ En ejemplos/demos
// example/, demo/, sample/ - archivos excluidos
```

## Configuración
```yaml
custom_lint:
  rules:
    no_local_datetime_constructors: true
```

## Solución recomendada

### ❌ Antes (problemático)
```dart
class OrderService {
  Order createOrder() {
    return Order(
      id: generateId(),
      createdAt: DateTime.now(), // ❌ No testeable
    );
  }
}
```

### ✅ Después (testeable)
```dart
class OrderService {
  final Clock _clock;
  
  OrderService(this._clock);
  
  Order createOrder() {
    return Order(
      id: generateId(),
      createdAt: _clock.now().toUtc(), // ✅ Testeable
    );
  }
}

// En tests:
test('creates order with correct timestamp', () {
  final fixedClock = Clock.fixed(DateTime(2025, 1, 17));
  final service = OrderService(fixedClock);
  
  final order = service.createOrder();
  
  expect(order.createdAt, DateTime(2025, 1, 17));
});
```

## Casos de uso común

### Servicios con timestamps
```dart
// ❌ Antes
class LogService {
  void log(String message) {
    print('${DateTime.now()}: $message'); // ❌
  }
}

// ✅ Después  
class LogService {
  final Clock _clock;
  LogService(this._clock);
  
  void log(String message) {
    print('${_clock.now().toUtc()}: $message'); // ✅
  }
}
```

### ViewModels
```dart
// ❌ Antes
class TaskViewModel extends ChangeNotifier {
  void createTask(String title) {
    final task = Task(
      title: title,
      createdAt: DateTime.now(), // ❌
    );
    _repository.save(task);
  }
}

// ✅ Después
class TaskViewModel extends ChangeNotifier {
  final Clock _clock;
  final TaskRepository _repository;
  
  TaskViewModel(this._clock, this._repository);
  
  void createTask(String title) {
    final task = Task(
      title: title,
      createdAt: _clock.now().toUtc(), // ✅
    );
    _repository.save(task);
  }
}
```

## Archivos excluidos
La regla NO se aplica en:
- `*_test.dart`
- Carpetas `test/`
- Carpetas `example/`
- Carpetas `demo/`
- Carpetas `sample/`

## Testing
Para probar esta regla:

```bash
dart run custom_lint
```

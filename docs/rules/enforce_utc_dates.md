# enforce_utc_dates

**Fechas en UTC para persistencia**

## 🎯 Resumen

Esta regla detecta fechas DateTime que no están en UTC en la capa de datos/persistencia y sugiere usar `.toUtc()` para evitar problemas de zona horaria.

## 📋 Guideline implementada

**Invariante**: "Fechas internas en UTC; conversión a UI"

## ⚠️ Problema detectado

Fechas no-UTC en persistencia causan:
- **Inconsistencias entre zonas horarias** en apps globales
- **Bugs al sincronizar** entre dispositivos en diferentes regiones
- **Problemas offline-first** cuando se cambia zona horaria
- **Ordenamiento incorrecto** por timestamps locales
- **Errores de lógica** en comparaciones de fechas

## ✅ Código correcto (no alertará)

```dart
// ✅ data/datasources/user_datasource.dart - UTC para persistencia
class UserDatasource {
  Future<void> saveUser(User user) async {
    final userData = {
      'id': user.id,
      'name': user.name,
      'created_at': DateTime.now().toUtc().toIso8601String(), // ✅ UTC
      'updated_at': _clock.now().toUtc().millisecondsSinceEpoch, // ✅ UTC
    };
    await _database.insert('users', userData);
  }

  User _fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['created_at'],
        isUtc: true, // ✅ Explícitamente UTC
      ),
    );
  }
}

// ✅ models/user_model.dart - Usando DateTime.utc
class UserModel {
  final DateTime createdAt;

  UserModel({required this.createdAt});

  factory UserModel.create(String name) {
    return UserModel(
      createdAt: DateTime.utc(2024, 1, 15), // ✅ Constructor UTC
    );
  }
}
```

### UI layer - permitido usar fechas locales
```dart
// ✅ presentation/pages/user_page.dart - Local para UI está OK
class UserPage extends StatelessWidget {
  Widget build(BuildContext context) {
    return Text(
      DateFormat.yMd().format(user.createdAt.toLocal()), // ✅ Local para UI
    );
  }
}
```

## ❌ Código incorrecto (alertará)

```dart
// ❌ data/datasources/user_datasource.dart - Fechas sin UTC
class UserDatasource {
  Future<void> saveUser(User user) async {
    final userData = {
      'created_at': DateTime.now().toIso8601String(), // ⚠️ FALTA .toUtc()
      'timestamp': DateTime.now().millisecondsSinceEpoch, // ⚠️ FALTA .toUtc()
    };
  }

  User _parseUser(String json) {
    return User(
      createdAt: DateTime.parse(jsonData['date']), // ⚠️ Sin .toUtc()
    );
  }
}

// ❌ models/event_model.dart - Constructor sin UTC
class EventModel {
  final DateTime scheduledAt;

  EventModel() : scheduledAt = DateTime(2024, 12, 25); // ⚠️ Constructor local
}

// ❌ repositories/sync_repository.dart - Timestamps locales
class SyncRepository {
  Future<void> markSynced() async {
    final now = DateTime.now(); // ⚠️ FALTA .toUtc()
    await _updateTimestamp(now.millisecondsSinceEpoch); // ⚠️ Timestamp local
  }
}
```

## 🔧 Cómo corregir

### 1. DateTime.now() → DateTime.now().toUtc()
```dart
// ❌ Fecha local
final timestamp = DateTime.now();

// ✅ Fecha UTC
final timestamp = DateTime.now().toUtc();
```

### 2. DateTime.parse() → DateTime.parse().toUtc()
```dart
// ❌ Parse sin conversión
final date = DateTime.parse('2024-01-15T10:30:00');

// ✅ Parse con conversión UTC
final date = DateTime.parse('2024-01-15T10:30:00').toUtc();
```

### 3. Constructor → DateTime.utc() o isUtc: true
```dart
// ❌ Constructor local
final date = DateTime(2024, 1, 15, 10, 30);

// ✅ Constructor UTC
final date = DateTime.utc(2024, 1, 15, 10, 30);

// ✅ FromMilliseconds con UTC
final date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
```

### 4. Milliseconds → .toUtc().millisecondsSinceEpoch
```dart
// ❌ Milliseconds de fecha local
final ms = someDate.millisecondsSinceEpoch;

// ✅ Milliseconds de fecha UTC
final ms = someDate.toUtc().millisecondsSinceEpoch;
```

## 🎯 Scope de la regla

**Detecta en archivos que contienen:**
- `data/` - Capa de datos
- `datasource/`, `datasources/` - Fuentes de datos
- `repository/`, `repositories/` - Repositorios
- `infrastructure/` - Infraestructura
- `models/` - Modelos de datos
- `entities/` - Entidades con serialización

**No detecta en:**
- `presentation/`, `ui/`, `pages/`, `widgets/` - UI layer
- `test/` - Tests
- Otros archivos fuera de data layer

## 🕐 Casos de uso comunes

### Timestamps para sincronización
```dart
// ✅ Correcto
class SyncManager {
  Future<void> syncData() async {
    final lastSync = DateTime.now().toUtc();
    await _saveSyncTimestamp(lastSync.millisecondsSinceEpoch);
  }
}
```

### Logs y auditoría
```dart
// ✅ Correcto
class AuditLogger {
  void logAction(String action) {
    final entry = AuditEntry(
      action: action,
      timestamp: DateTime.now().toUtc(), // UTC para logs
    );
    _database.save(entry);
  }
}
```

### Cache con expiración
```dart
// ✅ Correcto
class CacheEntry {
  final DateTime expiresAt;
  
  CacheEntry.withTtl(Duration ttl) 
    : expiresAt = DateTime.now().toUtc().add(ttl); // UTC para cache
}
```

## 🧪 Testing Guide

### Caso de prueba básico
```dart
// test_project/lib/data/user_datasource.dart
import 'dart:async';

class UserDatasource {
  Future<Map<String, dynamic>> saveUser(String name) async {
    return {
      'id': '123',
      'name': name,
      'created_at': DateTime.now().toIso8601String(), // ❌ Debe alertar
      'timestamp': DateTime.now().millisecondsSinceEpoch, // ❌ Debe alertar
    };
  }
  
  void parseDate(String dateStr) {
    final date = DateTime.parse(dateStr); // ❌ Debe alertar
    print('Parsed: $date');
  }
}
```

### Comando de prueba
```bash
cd test_project
dart run custom_lint

# Output esperado:
# lib/data/user_datasource.dart:7:18 • Dates in data/persistence layer should be in UTC. Use .toUtc() to prevent timezone inconsistencies. • enforce_utc_dates
# lib/data/user_datasource.dart:8:16 • Dates in data/persistence layer should be in UTC. Use .toUtc() to prevent timezone inconsistencies. • enforce_utc_dates
# lib/data/user_datasource.dart:13:17 • Dates in data/persistence layer should be in UTC. Use .toUtc() to prevent timezone inconsistencies. • enforce_utc_dates
```

### Verificar corrección
```dart
// Después de añadir .toUtc():
'created_at': DateTime.now().toUtc().toIso8601String(), // ✅ Corregido
'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch, // ✅ Corregido
final date = DateTime.parse(dateStr).toUtc(); // ✅ Corregido

// Resultado: Sin alertas
```

## 📊 Beneficios de usar UTC

**Consistencia global:**
- Misma referencia temporal en todos los dispositivos
- Sincronización confiable entre servidores
- Comparaciones de fechas precisas

**Offline-first apps:**
- Datos consistentes al cambiar zona horaria
- Resolución de conflictos más simple
- Cache y expiración predecibles

**Debugging:**
- Logs ordenados cronológicamente
- Easier troubleshooting across regions
- Timestamps comparables entre entornos

## 💡 Flujo recomendado

```dart
// 1. Input: Recibir fecha del usuario (puede ser local)
final userInput = DateTime.parse(userDateString);

// 2. Storage: Convertir a UTC para guardar
final utcDate = userInput.toUtc();
await repository.save(Event(scheduledAt: utcDate));

// 3. Business: Trabajar siempre en UTC
final events = await repository.getEventsBefore(DateTime.now().toUtc());

// 4. Display: Convertir a local para mostrar al usuario
final displayDate = event.scheduledAt.toLocal();
Text(DateFormat.yMd().format(displayDate));
```

## 🔗 Referencias

- [DateTime class - Dart API](https://api.dart.dev/stable/dart-core/DateTime-class.html)
- [Working with timezones in Flutter](https://docs.flutter.dev/cookbook/networking/authenticated-requests)
- [ISO 8601 DateTime standard](https://en.wikipedia.org/wiki/ISO_8601)
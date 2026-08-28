# no_external_dependencies_in_domain

**Domain sin dependencias externas (Clean Architecture)**

## 🎯 Resumen

Esta regla detecta imports de dependencias externas en el domain layer y sugiere usar dependency inversion para mantener el dominio puro según Clean Architecture.

## 📋 Guideline implementada

**Referencia**: Clean Architecture - "Nothing in an inner circle can know anything about something in an outer circle"  
**Invariante**: Domain debe ser Dart puro sin dependencias externas

## ⚠️ Problema detectado

Dependencias externas en domain causan:
- **Acoplamiento alto** con frameworks específicos
- **Dificultad para testing** (mocks complejos)
- **Portabilidad reducida** entre platforms
- **Violación de Clean Architecture** principles
- **Cambios costosos** cuando cambian dependencias

## ✅ Código correcto (no alertará)

```dart
// ✅ domain/entities/user.dart - Solo Dart puro
import 'dart:core';
import 'dart:async';
import 'package:meta/meta.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../value_objects/email.dart'; // Imports internos OK

@freezed
class User with _$User {
  const factory User({
    required String id,
    required Email email,
    required String name,
  }) = _User;
}

// ✅ domain/repositories/user_repository.dart - Abstracción pura
abstract class UserRepository {
  Future<User?> findById(String id);
  Future<void> save(User user);
  Future<List<User>> findByEmail(Email email);
}

// ✅ domain/usecases/get_user.dart - Business logic puro
class GetUserUseCase {
  final UserRepository _repository;
  
  GetUserUseCase(this._repository);
  
  Future<User?> execute(String id) async {
    return await _repository.findById(id);
  }
}
```

## ❌ Código incorrecto (alertará)

```dart
// ❌ domain/entities/user.dart - Dependencias prohibidas
import 'package:flutter/material.dart'; // ⚠️ Flutter framework
import 'package:dio/dio.dart'; // ⚠️ HTTP client
import 'package:provider/provider.dart'; // ⚠️ State management
import 'package:hive/hive.dart'; // ⚠️ Storage
import 'package:firebase_core/firebase_core.dart'; // ⚠️ Platform service

class User extends ChangeNotifier { // ❌ Acoplado a framework
  void updateName(String name) {
    // Logic aquí
    notifyListeners(); // ❌ Framework dependency
  }
}

// ❌ domain/repositories/user_repository.dart - Implementación concreta
import 'package:sqflite/sqflite.dart'; // ⚠️ Storage dependency

abstract class UserRepository {
  Database get database; // ❌ Expone implementación concreta
  Future<User?> findById(String id);
}

// ❌ domain/usecases/authenticate_user.dart - HTTP directo
import 'package:http/http.dart' as http; // ⚠️ Networking dependency

class AuthenticateUserUseCase {
  Future<bool> execute(String email, String password) async {
    final response = await http.post(/* ... */); // ❌ HTTP directo
    return response.statusCode == 200;
  }
}
```

## 🔧 Cómo corregir

### 1. Usar abstracciones en lugar de implementaciones
```dart
// ❌ En domain - dependencia concreta
import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio;
  // ...
}

// ✅ En domain - abstracción
abstract class HttpClient {
  Future<Map<String, dynamic>> get(String url);
  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> data);
}

// ✅ En infrastructure - implementación
import 'package:dio/dio.dart';

class DioHttpClient implements HttpClient {
  final Dio _dio;
  // Implementación específica aquí
}
```

### 2. Dependency inversion para servicios
```dart
// ❌ En domain - servicio concreto
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  SharedPreferences? _prefs;
  // ...
}

// ✅ En domain - abstracción
abstract class StorageService {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

// ✅ En infrastructure - implementación
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesStorage implements StorageService {
  // Implementación específica
}
```

### 3. Value objects para datos primitivos
```dart
// ❌ En domain - expone framework
import 'package:flutter/material.dart';

class User {
  final Color themeColor; // ❌ Flutter Color
}

// ✅ En domain - value object puro
class User {
  final ColorValue themeColor; // ✅ Value object custom
}

class ColorValue {
  final int red, green, blue;
  const ColorValue(this.red, this.green, this.blue);
}
```

## 🚫 Dependencias categorizadas

### ❌ **Completamente prohibidas**

| Categoría | Packages | Razón |
|-----------|----------|-------|
| **Flutter Framework** | `flutter/*` | UI framework específico |
| **State Management** | `provider`, `bloc`, `riverpod`, `get`, `mobx` | Gestión de estado de UI |
| **HTTP/Network** | `dio`, `http`, `chopper`, `retrofit` | Implementaciones de red |
| **Storage/Database** | `hive`, `sqflite`, `shared_preferences`, `sembast`, `drift` | Persistencia específica |
| **Platform Services** | `path_provider`, `device_info`, `permission_handler` | APIs específicas de platform |
| **Firebase** | `firebase_*`, `cloud_firestore` | Servicios cloud específicos |
| **Navigation/UI** | `go_router`, `auto_route` | Navegación de UI |

### ✅ **Permitidas (con justificación)**

| Package | Uso permitido | Justificación |
|---------|---------------|---------------|
| `dart:*` | Cualquier import de Dart core | Parte del lenguaje |
| `meta` | Annotations como `@required` | Metadatos de desarrollo |
| `freezed_annotation` | Generación de code inmutable | Facilita value objects |
| `json_annotation` | Serialización declarativa | Solo annotations |
| `equatable` | Equality comparisons | Utility puro |
| `dartz` | Functional programming | Patterns matemáticos puros |

## 🎯 Scope de la regla

**Detecta en:**
- Archivos dentro de carpetas `domain/`
- Subcarpetas como `domain/entities/`, `domain/repositories/`, etc.
- Archivos de cualquier profundidad en domain

**No detecta en:**
- Archivos fuera de `domain/`
- Carpetas `infrastructure/`, `presentation/`, `data/`
- Tests (aunque pueden estar en `test/domain/`)

## 🧪 Testing Guide

### Caso de prueba básico
```dart
// test_project/lib/domain/entities/user.dart
import 'package:flutter/material.dart'; // ❌ Debe alertar
import 'package:dio/dio.dart'; // ❌ Debe alertar
import 'package:meta/meta.dart'; // ✅ Permitido

@immutable
class User {
  final String id;
  final String name;
  
  const User({required this.id, required this.name});
}
```

### Comando de prueba
```bash
cd test_project
dart run custom_lint

# Output esperado:
# lib/domain/entities/user.dart:1:8 • Domain layer should not depend on Flutter framework packages. This violates Clean Architecture principles. • no_external_dependencies_in_domain
# lib/domain/entities/user.dart:2:8 • Domain layer should not depend on networking packages. This violates Clean Architecture principles. • no_external_dependencies_in_domain
```

### Estructura de proyecto ejemplo
```
lib/
├── domain/
│   ├── entities/
│   │   └── user.dart          # ← Regla aplica aquí
│   ├── repositories/
│   │   └── user_repository.dart # ← Regla aplica aquí
│   └── usecases/
│       └── get_user.dart      # ← Regla aplica aquí
├── infrastructure/
│   └── user_repository_impl.dart # ← Regla NO aplica
└── presentation/
    └── user_page.dart         # ← Regla NO aplica
```

## 🔧 Patrón de corrección

### Antes (❌ Violación)
```dart
// domain/repositories/user_repository.dart
import 'package:sqflite/sqflite.dart';

abstract class UserRepository {
  Database get database; // Expone implementación
  Future<User?> findById(String id);
}
```

### Después (✅ Corregido)
```dart
// domain/repositories/user_repository.dart
// Solo imports permitidos o internos

abstract class UserRepository {
  Future<User?> findById(String id);
  Future<void> save(User user);
  Future<List<User>> findAll();
}

// infrastructure/repositories/sqflite_user_repository.dart
import 'package:sqflite/sqflite.dart'; // OK aquí
import '../../domain/repositories/user_repository.dart';

class SqliteUserRepository implements UserRepository {
  final Database _database;
  // Implementación específica
}
```

## 📊 Beneficios de cumplir la regla

**Testabilidad:**
- Mocks simples (solo interfaces)
- Tests rápidos (sin dependencias externas)
- Tests unitarios puros

**Mantenibilidad:**
- Cambios de framework no afectan domain
- Business logic independiente
- Refactoring más seguro

**Portabilidad:**
- Domain reutilizable entre platforms
- Migración entre frameworks más fácil
- Lógica business agnóstica

## 🔗 Referencias

- [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Dependency Inversion Principle](https://en.wikipedia.org/wiki/Dependency_inversion_principle)
- [Flutter Clean Architecture Guide](https://resocoder.com/2019/08/27/flutter-tdd-clean-architecture-course-1-explanation-project-structure/)
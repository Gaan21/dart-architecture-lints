<!-- example-scope: isolated no_direct_internet_calls -->

> **Example contract: `no_direct_internet_calls` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_direct_internet_calls

**Calls HTTP via NetworkService centralizado**

## 🎯 Resumen

Esta regla detecta llamadas HTTP directas fuera de NetworkService y sugiere usar el servicio centralizado para mejor manejo de conectividad offline.

## 📋 Guideline implementada

**Invariante**: "Conectividad real verificación multi-endpoint 204 con timeouts cortos"

## ⚠️ Problema detectado

Llamadas HTTP directas causan:
- **Falta de verificación de conectividad** consistente
- **Manejo offline inconsistente** entre features
- **Timeout policies dispersas** y difíciles de mantener
- **Duplicación de lógica** de retry y error handling
- **Testing complejo** por múltiples puntos de red

## ✅ Código correcto (no alertará)

```dart
// ✅ services/network_service.dart - Servicio centralizado
class NetworkService {
  final Dio _dio;

  Future<bool> hasConnection() async {
    try {
      // ✅ Permitido: lógica de conectividad centralizada
      final response = await _dio.get(
        'https://clients3.google.com/generate_204',
        options: Options(
          connectTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 5),
        ),
      );
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<Response<T>> get<T>(String path) async {
    if (!await hasConnection()) {
      throw NoInternetException();
    }
    // ✅ Permitido: HTTP calls en servicio de red
    return await _dio.get<T>(path);
  }
}

// ✅ repositories/user_repository.dart - Usando NetworkService
class UserRepository {
  final NetworkService _networkService;
  final UserLocalDatasource _localDatasource;

  Future<List<User>> getUsers() async {
    try {
      // ✅ Via NetworkService
      final response = await _networkService.get('/users');
      final users = response.data.map((json) => User.fromJson(json)).toList();
      await _localDatasource.saveUsers(users);
      return users;
    } on NoInternetException {
      // ✅ Fallback offline
      return await _localDatasource.getUsers();
    }
  }
}

// ✅ infrastructure/api_client.dart - Cliente HTTP dedicado
class ApiClient {
  final Dio _dio;

  Future<UserDto> fetchUser(String id) async {
    // ✅ Permitido: archivos de clientes HTTP dedicados
    final response = await _dio.get('/users/$id');
    return UserDto.fromJson(response.data);
  }
}
```

## ❌ Código incorrecto (alertará)

```dart
// ❌ repositories/user_repository.dart - HTTP directo
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class UserRepository {
  Future<List<User>> getUsers() async {
    // ❌ Connectividad directa
    final connectivity = await Connectivity().checkConnectivity(); // ⚠️ DIRECTO
    
    if (connectivity != ConnectivityResult.none) {
      // ❌ HTTP directo sin NetworkService
      final dio = Dio(); // ⚠️ INSTANCIA DIRECTA
      final response = await dio.get('https://api.com/users'); // ⚠️ CALL DIRECTO
      return response.data.map((json) => User.fromJson(json)).toList();
    }
    
    return [];
  }
}

// ❌ usecases/sync_data_usecase.dart - HTTP en caso de uso
import 'package:http/http.dart' as http;

class SyncDataUseCase {
  Future<void> execute() async {
    // ❌ HTTP directo en caso de uso
    final response = await http.get(Uri.parse('https://api.com/sync')); // ⚠️ DIRECTO
    
    if (response.statusCode == 200) {
      // Process data
    }
  }
}

// ❌ presentation/controllers/user_controller.dart - HTTP en controller
class UserController {
  Future<void> refreshUsers() async {
    final client = http.Client(); // ⚠️ CLIENTE DIRECTO
    final response = await client.post( // ⚠️ CALL DIRECTO
      Uri.parse('https://api.com/refresh'),
    );
    client.close();
  }
}
```

## 🔧 Cómo corregir

### 1. Crear NetworkService centralizado
```dart
// services/network_service.dart
class NetworkService {
  final Dio _dio;
  
  NetworkService(this._dio);

  Future<bool> hasConnection() async {
    try {
      final response = await _dio.get(
        'https://clients3.google.com/generate_204',
        options: Options(
          connectTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 5),
        ),
      );
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<Response<T>> get<T>(String path) async {
    if (!await hasConnection()) {
      throw NoInternetException();
    }
    return await _dio.get<T>(path);
  }

  // Métodos para POST, PUT, DELETE...
}
```

### 2. Refactorizar repositorio para usar NetworkService
```dart
// ❌ Antes - HTTP directo
class UserRepository {
  Future<List<User>> getUsers() async {
    final dio = Dio();
    final response = await dio.get('/users');
    return response.data.map((json) => User.fromJson(json)).toList();
  }
}

// ✅ Después - Via NetworkService
class UserRepository {
  final NetworkService _networkService;
  final UserLocalDatasource _localDatasource;
  
  UserRepository(this._networkService, this._localDatasource);

  Future<List<User>> getUsers() async {
    try {
      final response = await _networkService.get('/users');
      final users = response.data.map((json) => User.fromJson(json)).toList();
      await _localDatasource.saveUsers(users);
      return users;
    } on NoInternetException {
      return await _localDatasource.getUsers();
    }
  }
}
```

### 3. Dependency injection para NetworkService
```dart
// main.dart o DI setup
void setupDependencies() {
  // Registro de NetworkService
  GetIt.instance.registerSingleton<NetworkService>(
    NetworkService(Dio()),
  );
  
  // Repositories usando NetworkService
  GetIt.instance.registerFactory<UserRepository>(
    () => UserRepository(
      GetIt.instance<NetworkService>(),
      GetIt.instance<UserLocalDatasource>(),
    ),
  );
}
```

## 🎯 Scope de la regla

### ✅ **Permitido en estos archivos:**
- `*network_service*` - Servicios de red
- `*connectivity_service*` - Servicios de conectividad  
- `*http_service*` - Servicios HTTP
- `*api_service*` - Servicios API
- `*dio_service*` - Servicios Dio
- Archivos en carpetas `network/` o `services/` que contengan `service` o `client`

### ❌ **No permitido en:**
- `repositories/` - Repositorios
- `usecases/` - Casos de uso
- `controllers/` - Controladores
- `presentation/` - Capa de presentación
- `domain/` - Capa de dominio
- Cualquier archivo fuera de servicios de red dedicados

## 📡 Calls detectados

### HTTP Method calls
- `get()`, `post()`, `put()`, `delete()`, `patch()`, `head()`, `options()`
- En contextos de: `Dio()`, `http.*`, instancias de HTTP clients

### Network instances
- `Dio()` - Cliente HTTP Dio
- `http.Client()` - Cliente HTTP estándar
- `HttpClient()`, `IOClient()`, `BrowserClient()` - Clientes específicos

### Connectivity checks
- `Connectivity().checkConnectivity()`
- `*.hasConnection()`, `*.isConnected()` en instancias directas

## 🧪 Testing Guide

### Caso de prueba básico
```dart
// test_project/lib/repositories/user_repository.dart
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class UserRepository {
  Future<Map<String, dynamic>> fetchUser(String id) async {
    // ❌ Todas estas líneas deben alertar
    final connectivity = Connectivity(); // ⚠️ Instancia directa
    final result = await connectivity.checkConnectivity(); // ⚠️ Check directo
    
    if (result != ConnectivityResult.none) {
      final dio = Dio(); // ⚠️ Instancia HTTP directa
      final response = await dio.get('/users/$id'); // ⚠️ HTTP call directo
      return response.data;
    }
    
    return {};
  }
}
```

### Comando de prueba
```bash
cd test_project
dart run custom_lint

# Output esperado:
# lib/repositories/user_repository.dart:6:22 • Direct Connectivity instances should be managed by NetworkService for centralized handling. • no_direct_internet_calls
# lib/repositories/user_repository.dart:7:23 • Direct connectivity checks should go through NetworkService for consistent offline handling. • no_direct_internet_calls
# lib/repositories/user_repository.dart:10:17 • Direct internet calls should go through NetworkService for centralized connectivity and offline handling. • no_direct_internet_calls
# lib/repositories/user_repository.dart:11:25 • Direct internet calls should go through NetworkService for centralized connectivity and offline handling. • no_direct_internet_calls
```

### Verificar corrección
```dart
// Después de refactorizar con NetworkService:
class UserRepository {
  final NetworkService _networkService;
  
  UserRepository(this._networkService);

  Future<Map<String, dynamic>> fetchUser(String id) async {
    try {
      final response = await _networkService.get('/users/$id'); // ✅ Via servicio
      return response.data;
    } on NoInternetException {
      return {}; // Fallback offline
    }
  }
}

// Resultado: Sin alertas
```

## 🔄 Patrón NetworkService recomendado

```dart
// services/network_service.dart
class NetworkService {
  final Dio _dio;
  final List<String> _connectivityUrls = [
    'https://clients3.google.com/generate_204', // Google
    'https://www.gstatic.com/generate_204',     // Google backup
    'https://captive.apple.com/hotspot-detect.html', // Apple
  ];

  NetworkService(this._dio) {
    _dio.options = BaseOptions(
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
    );
  }

  Future<bool> hasConnection() async {
    // Multi-endpoint verification con timeouts cortos
    for (final url in _connectivityUrls) {
      try {
        final response = await _dio.get(
          url,
          options: Options(
            connectTimeout: Duration(seconds: 5),
            receiveTimeout: Duration(seconds: 5),
          ),
        );
        if (response.statusCode == 204 || response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        continue; // Try next endpoint
      }
    }
    return false;
  }

  Future<Response<T>> request<T>(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    if (!await hasConnection()) {
      throw NoInternetException('No internet connection available');
    }

    return await _dio.request<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(method: method),
    );
  }

  // Convenience methods
  Future<Response<T>> get<T>(String path) => request('GET', path);
  Future<Response<T>> post<T>(String path, {dynamic data}) => 
    request('POST', path, data: data);
  // ... más métodos
}

class NoInternetException implements Exception {
  final String message;
  NoInternetException(this.message);
}
```

## 📊 Beneficios del patrón centralizado

**Consistencia:**
- Misma lógica de conectividad en toda la app
- Timeouts uniformes y configurables
- Error handling centralizado

**Offline-first:**
- Verificación confiable multi-endpoint
- Fallback patterns consistentes
- Cache y retry policies centralizadas

**Testing:**
- Mock único de NetworkService
- Simulación de estados offline fácil
- Tests más rápidos y deterministas

**Mantenimiento:**
- Cambios de API en un solo lugar
- Monitoring y logs centralizados
- Configuración de red unificada

## 🔗 Referencias

- [Connectivity Plus Package](https://pub.dev/packages/connectivity_plus)
- [Dio HTTP Client](https://pub.dev/packages/dio)
- [Flutter Networking Guide](https://docs.flutter.dev/development/data-and-backend/networking)

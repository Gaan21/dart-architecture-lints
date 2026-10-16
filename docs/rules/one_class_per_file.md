<!-- example-scope: isolated one_class_per_file -->

> **Example contract: `one_class_per_file` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# one_class_per_file

**Nivel**: MEDIO | **Tipo**: Architectural | **Área**: File Structure

## Descripción

Esta regla enforza estrictamente una clase pública principal por archivo. **Solo permite subclases directas** de la clase principal en el mismo archivo. **Prohíbe enums y mixins independientes**, requiriendo que vayan en archivos separados.

## ¿Por qué es importante?

- **Single Responsibility**: Un archivo, una responsabilidad principal
- **Navigation clarity**: Facilita encontrar tipos específicos
- **Code organization**: Estructura predecible del proyecto
- **Import precision**: Imports más específicos y claros
- **Team collaboration**: Evita conflictos de merge

## Ejemplos

### ✅ Código correcto (no debe alertar)

```dart
// archivo: user.dart - Una clase principal
class User {
  final String id;
  final String name;
  final String email;
  
  User({required this.id, required this.name, required this.email});
  
  void updateProfile(String newName) {
    // logic
  }
}

// ✅ SOLO subclases DIRECTAS permitidas
class AdminUser extends User {
  final List<String> permissions;
  
  AdminUser({
    required super.id,
    required super.name,
    required super.email,
    required this.permissions,
  });
}

class GuestUser extends User {
  GuestUser() : super(id: 'guest', name: 'Guest', email: '');
}

// ✅ Clases private siempre permitidas
class _UserValidator {
  static bool isValidEmail(String email) => email.contains('@');
}

class _UserHelper {
  static String formatName(String name) => name.trim();
}
```

### ❌ Código incorrecto (debe alertar)

```dart
// archivo: bad_models.dart - Múltiples tipos independientes
class User {
  final String name;
  final String email;
  
  User(this.name, this.email);
}

class Product { // ❌ Tipo independiente - debe ir en product.dart
  final String title;
  final double price;
  
  Product(this.title, this.price);
}

enum UserStatus { // ❌ Enum independiente - debe ir en user_status.dart
  active,
  inactive,
  banned
}

mixin TimestampMixin { // ❌ Mixin independiente - debe ir en timestamp_mixin.dart
  DateTime get createdAt;
  DateTime get updatedAt;
}

class Order { // ❌ Otra clase independiente - debe ir en order.dart
  final String id;
  final User customer;
  
  Order(this.id, this.customer);
}
```

### ❌ Clases relacionadas pero NO subclases directas

```dart
// archivo: user_domain.dart - Relaciones que NO están permitidas
class User {
  final String name;
  User(this.name);
}

class UserRepository { // ❌ NO es subclase directa - debe ir en user_repository.dart
  Future<User> findById(String id) async {
    // Implementation
  }
}

class UserService { // ❌ NO es subclase directa - debe ir en user_service.dart
  final UserRepository repository;
  UserService(this.repository);
}

class UserException extends Exception { // ❌ NO es subclase de User - debe ir en user_exception.dart
  final String message;
  UserException(this.message);
}
```

## Regla estricta: Solo subclases directas

La regla **SOLO** permite estos casos en el mismo archivo que la clase principal:

### ✅ Permitido: Herencia directa
```dart
// animal.dart
abstract class Animal {
  void makeSound();
}

class Dog extends Animal { // ✅ Subclase directa de Animal
  @override
  void makeSound() => print('Woof!');
}

class Cat extends Animal { // ✅ Subclase directa de Animal
  @override
  void makeSound() => print('Meow!');
}
```

### ❌ NO permitido: Herencia indirecta
```dart
// shapes.dart
abstract class Shape {}

class Rectangle extends Shape {}

class Square extends Rectangle { // ❌ NO es subclase directa de Shape
  // Debe ir en square.dart
}
```

### ❌ NO permitido: Enums relacionados
```dart
// user.dart  
class User {
  final UserStatus status;
}

enum UserStatus { // ❌ Debe ir en user_status.dart
  active, inactive
}
```

### ❌ NO permitido: Mixins relacionados
```dart
// user.dart
class User with Timestamped {
  final String name;
}

mixin Timestamped { // ❌ Debe ir en timestamped.dart
  DateTime get createdAt;
}
```

## Casos detectados

La regla identifica y alerta sobre:

1. **Múltiples clases independientes** en el mismo archivo
2. **Enums públicos** (siempre deben ir separados)
3. **Mixins públicos** (siempre deben ir separados)
4. **Clases relacionadas pero no subclases directas**
5. **Herencia indirecta** (A -> B -> C, donde C no es subclase directa de A)

## Testing guide

### Setup de testing

```bash
dart create test_strict_organization
cd test_strict_organization
```

### Configuración

En `analysis_options.yaml`:
```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    - one_class_per_file
```

### Casos de prueba

Crea `lib/test_violations.dart`:

```dart
// ESTE ARCHIVO DEBE GENERAR 4 WARNINGS

// Clase principal (correcta)
class User {
  final String id;
  final String name;
  
  User({required this.id, required this.name});
}

// ✅ Esta subclase directa NO debe alertar
class AdminUser extends User {
  final bool isAdmin;
  AdminUser({required super.id, required super.name, this.isAdmin = true});
}

// ❌ Estas declaraciones SÍ deben alertar:

class Product { // ❌ WARNING: Clase independiente
  final String title;
  Product(this.title);
}

enum UserStatus { // ❌ WARNING: Enum independiente
  active,
  inactive
}

mixin LoggingMixin { // ❌ WARNING: Mixin independiente
  void log(String message) => print(message);
}

class OrderService { // ❌ WARNING: Otra clase independiente
  void processOrder() {}
}
```

Crea `lib/test_valid.dart`:

```dart
// ESTE ARCHIVO NO DEBE GENERAR WARNINGS

class Vehicle {
  final String brand;
  final String model;
  
  Vehicle({required this.brand, required this.model});
}

// ✅ Todas estas son subclases DIRECTAS de Vehicle - permitidas
class Car extends Vehicle {
  final int doors;
  Car({required super.brand, required super.model, required this.doors});
}

class Motorcycle extends Vehicle {
  final bool hasSidecar;
  Motorcycle({required super.brand, required super.model, this.hasSidecar = false});
}

class Truck extends Vehicle {
  final double capacity;
  Truck({required super.brand, required super.model, required this.capacity});
}

// ✅ Clases private siempre permitidas
class _VehicleHelper {
  static String format(String text) => text.toUpperCase();
}
```

### Verificación

```bash
dart run custom_lint
```

**Resultado esperado**:
- `test_violations.dart`: 4 warnings (Product, UserStatus, LoggingMixin, OrderService)
- `test_valid.dart`: 0 warnings

## Configuración

Esta regla no requiere configuración. Aplica automáticamente a:

- **Archivos Dart regulares**: Todos excepto tests y generados
- **Tipos públicos**: Clases, enums, mixins que no empiezan con `_`
- **Criterio estricto**: Solo subclases directas permitidas

## Algoritmo de detección

1. **Identifica tipos públicos** (clases, enums, mixins)
2. **Si hay múltiples tipos**:
   - Encuentra la clase principal (más grande o primera)
   - **Enums y mixins siempre alertan** (deben ir separados)
   - **Clases solo permitidas si extienden directamente** la clase principal
3. **Si no hay clase principal**, todos los tipos adicionales alertan

## Impacto en performance

- **Análisis**: Moderado - examina estructura completa de archivos
- **Aplicación**: Alto beneficio - organización strict y predecible
- **Falsos positivos**: Muy bajos - criterio claro y objetivo

## Relación con otras reglas

- Complementa reglas de naming conventions
- Refuerza Single Responsibility Principle
- Trabaja junto con import organization

## Referencias

- [Clean Code - Classes](https://cleancodetips.com/clean-code-classes)
- [Single Responsibility Principle](https://en.wikipedia.org/wiki/Single-responsibility_principle)
- [Effective Dart - Design](https://dart.dev/guides/language/effective-dart/design)

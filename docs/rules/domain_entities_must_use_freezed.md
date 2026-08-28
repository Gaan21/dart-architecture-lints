# domain_entities_must_use_freezed

**Rule name**: `domain_entities_must_use_freezed`
**Type**: Error
**Severity**: 🔴 Critical

## Overview

Enforces the use of `@freezed` annotation on all domain entities. This ensures guaranteed immutability, automatic pattern matching, and `copyWith()` methods for entities in the domain layer.

## Rationale

Domain entities must be immutable to prevent side effects and ensure data consistency across the application. While Dart's `final` keyword provides compile-time immutability, `@freezed` guarantees:

1. **Deep immutability**: All fields are truly immutable
2. **Pattern matching**: Sealed unions for state management
3. **copyWith()**: Safe modifications creating new instances
4. **Equality**: Automatic `==` and `hashCode` implementation

Without this enforcement, developers might create entities with standard classes that appear immutable but lack these guarantees.

## ❌ Bad (will trigger the rule)

```dart
// lib/domain/entities/user.dart
class User {
  final String id;
  final String name;
  final String email;

  User({
    required this.id,
    required this.name,
    required this.email,
  });
}

// lib/domain/entities/product.dart
class Product {
  final String id;
  final String name;
  final double price;

  const Product({
    required this.id,
    required this.name,
    required this.price,
  });
}

// lib/domain/value_objects/email.dart
class Email {
  final String value;

  Email(this.value);
}
```

## ✅ Good (will not trigger the rule)

```dart
// lib/domain/entities/user.dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
  }) = _User;
}

// lib/domain/entities/product.dart
@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String name,
    required double price,
  }) = _Product;
}

// lib/domain/value_objects/email.dart
@freezed
class Email with _$Email {
  const factory Email({
    required String value,
  }) = _Email;
}

// lib/domain/entities/user_repository.dart
// ✅ Abstract interfaces don't need @freezed
abstract interface class UserRepository {
  Future<Result<User>> getById(String id);
  Future<Result<void>> save(User user);
}
```

## Exception Cases

The rule does **NOT** apply to:

1. **Abstract interface classes**: Pure contracts that define behavior
   ```dart
   abstract interface class UserRepository {
     Future<Result<User>> getById(String id);
   }
   ```

2. **Generated files**: `.freezed.dart`, `.g.dart` files are automatically ignored

3. **Private classes**: Classes starting with `_` (usually generated code)

## Problem Message

> Las entidades de domain deben declararse con @freezed para garantizar inmutabilidad y pattern matching.

## Correction Message

> Anota la clase con @freezed, cambia a const factory, y mueve los campos al factory constructor.
> Ejemplo:
>   @freezed
>   class User with _$User {
>     const factory User({required String id, required String name}) = _User;
>   }

## How to Test This Rule

### Setup Test Project

1. Navigate to a separate Flutter project that consumes this package
2. Ensure `dart_architecture_lints` is added as dependency
3. Add rule to `analysis_options.yaml`:
   ```yaml
   custom_lint:
     rules:
       domain_entities_must_use_freezed: error
   ```

### Test Cases

**File: `lib/domain/entities/test_user.dart`**
```dart
// ❌ Should trigger the rule
class User {
  final String id;
  final String name;

  User({required this.id, required this.name});
}
```

**File: `lib/domain/entities/test_product.dart`**
```dart
// ✅ Should NOT trigger
@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String name,
  }) = _Product;
}
```

**File: `lib/domain/entities/test_repository.dart`**
```dart
// ✅ Should NOT trigger (abstract interface)
abstract interface class ProductRepository {
  Future<Result<Product>> getById(String id);
}
```

**File: `lib/data/models/user_model.dart`**
```dart
// ✅ Should NOT trigger (not in domain/entities/ or domain/value_objects/)
class UserModel {
  final String id;
  final String name;

  UserModel({required this.id, required this.name});
}
```

### Expected Results

Run `dart run custom_lint` and verify:
- ❌ 1 error in `test_user.dart`
- ✅ 0 errors in `test_product.dart` (has @freezed)
- ✅ 0 errors in `test_repository.dart` (abstract interface)
- ✅ 0 errors in `user_model.dart` (not in domain/)

### Troubleshooting

If the rule doesn't work as expected:

1. **Check path detection**: Rule only applies to `lib/domain/entities/` and `lib/domain/value_objects/`
2. **Verify @freezed package**: Ensure `freezed_annotation` is in dependencies
3. **Check abstract classes**: Abstract classes should be excluded
4. **Generated files**: Ensure `.freezed.dart` files are not being flagged

## Guideline Alignment

This rule directly implements the guideline from the project architecture guidelines and `01A_ARCHITECTURE.md:78`:

> "Freezed OBLIGATORIO para entidades de dominio"

**✅ CORRECTO**:
```dart
@freezed
class User with _$User {
  const factory User({required String id, required String name}) = _User;
}
```

**❌ INCORRECTO**:
```dart
class User {
  final String id;
  final String name;
  User({required this.id, required this.name});
}
```

## Related Rules

- `no_serialization_in_entities` - Prevents serialization logic in entities
- `models_must_have_json_serialization` - Enforces serialization in data models
- `no_external_dependencies_in_domain` - Maintains clean architecture boundaries

## Implementation Notes

- Uses `ClassDeclaration` AST node visitor
- Checks for `@freezed` or `@Freezed` metadata annotations
- Path-based filtering for domain layer (`/domain/entities/`, `/domain/value_objects/`)
- Excludes abstract classes (no concrete implementation required)
- Excludes private classes starting with `_`
- Inherits from `GeneratedSkippingDartLintRule` to skip generated files automatically

<!-- example-scope: isolated no_serialization_in_entities -->

> **Example contract: `no_serialization_in_entities` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_serialization_in_entities

**Rule name**: `no_serialization_in_entities`
**Type**: Error
**Severity**: 🔴 Critical

## Overview

Prevents the use of JSON serialization methods (`fromJson`, `toJson`) and annotations (`@JsonSerializable`, `@JsonKey`) in domain entities. Serialization belongs exclusively to the data layer (Models), maintaining strict separation between domain and data concerns.

## Rationale

In Clean Architecture, the domain layer must be independent of infrastructure concerns like JSON serialization:

1. **Domain independence**: Entities represent pure business logic without external format knowledge
2. **Separation of concerns**: Serialization is a data layer responsibility
3. **Testability**: Domain entities remain simple and easy to test
4. **Flexibility**: Changing API format doesn't affect domain

This rule enforces the invariant from guidelines: "Serialización solo en data (Models). Entidades no llevan toJson/fromJson" (00_SUMMARY.md:12)

## ❌ Bad (will trigger the rule)

```dart
// lib/domain/entities/user.dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
  }) = _User;

  // ❌ Serialization in entity
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

// lib/domain/entities/product.dart
@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String name,
    required double price,
  }) = _Product;

  // ❌ toJson in entity
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}

// lib/domain/value_objects/email.dart
@JsonSerializable()  // ❌ Annotation in entity
class Email {
  @JsonKey(name: 'email_address')  // ❌ JsonKey in entity
  final String value;

  Email(this.value);

  factory Email.fromJson(Map<String, dynamic> json) => _$EmailFromJson(json);
  Map<String, dynamic> toJson() => _$EmailToJson(this);
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
  // ✅ No serialization methods
}

// lib/data/models/user_model.dart
@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String name,
    required String email,
  }) = _UserModel;

  // ✅ Serialization in model (data layer)
  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}

// lib/data/mappers/user_mapper.dart
class UserMapper {
  // ✅ Conversion between model and entity
  static User toEntity(UserModel model) {
    return User(
      id: model.id,
      name: model.name,
      email: model.email,
    );
  }

  static UserModel toModel(User entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
    );
  }
}
```

## Exception Cases

The rule does **NOT** apply to:

1. **Generated files**: `.freezed.dart`, `.g.dart` files are automatically ignored
2. **Files outside domain**: Only applies to `lib/domain/entities/` and `lib/domain/value_objects/`
3. **Abstract interfaces**: Pure contract definitions (though they shouldn't have serialization anyway)

## Problem Message

> Las entidades de domain no deben tener métodos de serialización (fromJson/toJson). La serialización pertenece a la capa data (Models).

## Correction Message

> Crea un Model correspondiente en lib/data/models/ con @freezed y métodos de serialización. Usa Mappers para convertir entre Model y Entity.
> Ejemplo:
>   // lib/data/models/user_model.dart
>   @freezed
>   class UserModel with _$UserModel {
>     const factory UserModel({required String id}) = _UserModel;
>     factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
>   }

## How to Test This Rule

### Setup Test Project

1. Navigate to a separate Flutter project that consumes this package
2. Ensure `dart_architecture_lints` is added as dependency
3. Add rule to `analysis_options.yaml`:
   ```yaml
   custom_lint:
     rules:
       no_serialization_in_entities: error
   ```

### Test Cases

**File: `lib/domain/entities/test_user_bad.dart`**
```dart
// ❌ Should trigger the rule
@freezed
class User with _$User {
  const factory User({required String id, required String name}) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

**File: `lib/domain/entities/test_product_bad.dart`**
```dart
// ❌ Should trigger on @JsonSerializable
@JsonSerializable()
@freezed
class Product with _$Product {
  const factory Product({required String id}) = _Product;
}
```

**File: `lib/domain/entities/test_user_good.dart`**
```dart
// ✅ Should NOT trigger
@freezed
class User with _$User {
  const factory User({required String id, required String name}) = _User;
  // No serialization methods
}
```

**File: `lib/data/models/user_model.dart`**
```dart
// ✅ Should NOT trigger (not in domain/)
@freezed
class UserModel with _$UserModel {
  const factory UserModel({required String id}) = _UserModel;
  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}
```

### Expected Results

Run `dart run custom_lint` and verify:
- ❌ 1 error in `test_user_bad.dart` (fromJson method)
- ❌ 1 error in `test_product_bad.dart` (@JsonSerializable annotation)
- ✅ 0 errors in `test_user_good.dart` (no serialization)
- ✅ 0 errors in `user_model.dart` (data layer is OK)

### Troubleshooting

If the rule doesn't work as expected:

1. **Check path detection**: Rule only applies to `lib/domain/entities/` and `lib/domain/value_objects/`
2. **Verify method detection**: Both `fromJson` and `toJson` methods should be flagged
3. **Check annotations**: `@JsonSerializable` and `@JsonKey` should be detected
4. **Constructor detection**: Factory constructors named `fromJson` should be flagged

## Guideline Alignment

This rule directly implements the guideline from the project architecture guidelines:

> "Serialización solo en data (Models). Entidades no llevan toJson/fromJson"

**✅ CORRECTO (Domain Entity)**:
```dart
// lib/domain/entities/user.dart
@freezed
class User with _$User {
  const factory User({required String id}) = _User;
}
```

**✅ CORRECTO (Data Model)**:
```dart
// lib/data/models/user_model.dart
@freezed
class UserModel with _$UserModel {
  const factory UserModel({required String id}) = _UserModel;
  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}
```

**❌ INCORRECTO**:
```dart
// lib/domain/entities/user.dart
@freezed
class User with _$User {
  const factory User({required String id}) = _User;
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);  // ❌
}
```

## Related Rules

- `domain_entities_must_use_freezed` - Enforces @freezed on entities
- `models_must_have_json_serialization` - Enforces serialization in data models
- `no_external_dependencies_in_domain` - Maintains clean architecture boundaries

## Implementation Notes

- Uses `ClassDeclaration` AST node visitor
- Detects method declarations with names `fromJson` and `toJson`
- Detects factory constructors with name `fromJson`
- Detects annotations `@JsonSerializable` and `@JsonKey`
- Path-based filtering for domain layer (`/domain/entities/`, `/domain/value_objects/`)
- Does NOT check imports (avoids false positives from unused imports)
- Inherits from `GeneratedSkippingDartLintRule` to skip generated files automatically
- Very low false positive rate (< 5%) due to precise scope and clear heuristics

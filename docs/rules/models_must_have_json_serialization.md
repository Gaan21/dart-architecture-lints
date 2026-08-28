# models_must_have_json_serialization

**Rule name**: `models_must_have_json_serialization`
**Type**: Warning
**Severity**: ⚠️ High Priority

## Overview

Enforces that data layer models have JSON serialization capabilities. Models must expose `fromJson`/`toJson` methods or use `@JsonSerializable`/`@freezed` annotations to interact with APIs.

## Rationale

Data models are the boundary between external data sources (APIs, databases) and the application. They must be able to serialize/deserialize to ensure:

1. **API communication**: Convert JSON responses to Dart objects
2. **Data persistence**: Store and retrieve data from local databases
3. **Type safety**: Prevent runtime errors from missing serialization
4. **Consistency**: Enforce architectural pattern across all models

This rule complements `no_serialization_in_entities` to maintain strict Domain/Data separation as specified in guidelines (01A_ARCHITECTURE.md:11-13).

## ❌ Bad (will trigger the rule)

```dart
// lib/data/models/user_model.dart
class UserModel {
  final String id;
  final String name;
  final String email;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
  });
  // ❌ Missing serialization methods
}

// lib/data/models/product_model.dart
@freezed
class ProductModel with _$ProductModel {
  const factory ProductModel({
    required String id,
    required String name,
    required double price,
  }) = _ProductModel;
  // ❌ Missing fromJson (even with @freezed)
}

// lib/data/models/order_model.dart
class OrderModel {
  final String id;
  final List<String> items;

  const OrderModel({required this.id, required this.items});

  // ❌ Only has fromJson, missing toJson
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      items: List<String>.from(json['items']),
    );
  }
}
```

## ✅ Good (will not trigger the rule)

```dart
// lib/data/models/user_model.dart - Option 1: @JsonSerializable
@JsonSerializable()
class UserModel {
  final String id;
  final String name;
  final String email;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}

// lib/data/models/product_model.dart - Option 2: @freezed with fromJson
@freezed
class ProductModel with _$ProductModel {
  const factory ProductModel({
    required String id,
    required String name,
    required double price,
  }) = _ProductModel;

  factory ProductModel.fromJson(Map<String, dynamic> json) => _$ProductModelFromJson(json);
}

// lib/data/models/order_model.dart - Option 3: Manual implementation
class OrderModel {
  final String id;
  final List<String> items;

  const OrderModel({required this.id, required this.items});

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      items: List<String>.from(json['items']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items,
    };
  }
}

// lib/data/models/internal_cache_model.dart - Option 4: Ignore for special cases
// ignore: models_must_have_json_serialization
class InternalCacheModel {
  // This model is only used for in-memory caching, never serialized
  final String key;
  final dynamic value;

  InternalCacheModel({required this.key, required this.value});
}
```

## Exception Cases

The rule does **NOT** apply to:

1. **Abstract classes**: Base classes that don't represent concrete data
   ```dart
   abstract class BaseModel {
     String get id;
   }
   ```

2. **Private classes**: Classes starting with `_` (usually internal/generated)

3. **Generated files**: `.freezed.dart`, `.g.dart` files are automatically ignored

4. **Explicitly ignored**: Models with `// ignore: models_must_have_json_serialization` comment

5. **Files outside data/models/**: Only applies to `lib/data/models/` directory

## Problem Message

> Los models de data deben exponer fromJson/toJson o usar @JsonSerializable para interactuar con APIs.

## Correction Message

> Genera los métodos con json_serializable o añade manualmente:
>   factory YourModel.fromJson(Map<String, dynamic> json) { ... }
>   Map<String, dynamic> toJson() { ... }
> O usa @freezed con fromJson:
>   @freezed
>   class YourModel with _$YourModel {
>     const factory YourModel({required String id}) = _YourModel;
>     factory YourModel.fromJson(Map<String, dynamic> json) => _$YourModelFromJson(json);
>   }

## How to Test This Rule

### Setup Test Project

1. Navigate to a separate Flutter project that consumes this package
2. Ensure `dart_architecture_lints` is added as dependency
3. Add rule to `analysis_options.yaml`:
   ```yaml
   custom_lint:
     rules:
       models_must_have_json_serialization: warning
   ```

### Test Cases

**File: `lib/data/models/test_user_model_bad.dart`**
```dart
// ❌ Should trigger the rule
class UserModel {
  final String id;
  final String name;

  UserModel({required this.id, required this.name});
}
```

**File: `lib/data/models/test_product_model_bad.dart`**
```dart
// ❌ Should trigger (missing fromJson even with @freezed)
@freezed
class ProductModel with _$ProductModel {
  const factory ProductModel({required String id}) = _ProductModel;
}
```

**File: `lib/data/models/test_user_model_good1.dart`**
```dart
// ✅ Should NOT trigger (@JsonSerializable)
@JsonSerializable()
class UserModel {
  final String id;

  UserModel({required this.id});

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
```

**File: `lib/data/models/test_user_model_good2.dart`**
```dart
// ✅ Should NOT trigger (@freezed with fromJson)
@freezed
class UserModel with _$UserModel {
  const factory UserModel({required String id}) = _UserModel;
  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}
```

**File: `lib/data/models/test_user_model_good3.dart`**
```dart
// ✅ Should NOT trigger (manual implementation)
class UserModel {
  final String id;

  UserModel({required this.id});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(id: json['id']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id};
  }
}
```

**File: `lib/domain/entities/user.dart`**
```dart
// ✅ Should NOT trigger (not in data/models/)
class User {
  final String id;
  User({required this.id});
}
```

### Expected Results

Run `dart run custom_lint` and verify:
- ⚠️ 1 warning in `test_user_model_bad.dart`
- ⚠️ 1 warning in `test_product_model_bad.dart`
- ✅ 0 warnings in `test_user_model_good1.dart` (@JsonSerializable)
- ✅ 0 warnings in `test_user_model_good2.dart` (@freezed + fromJson)
- ✅ 0 warnings in `test_user_model_good3.dart` (manual methods)
- ✅ 0 warnings in `user.dart` (domain entity)

### Troubleshooting

If the rule doesn't work as expected:

1. **Check path detection**: Rule only applies to `lib/data/models/`
2. **Verify annotation detection**: `@JsonSerializable` and `@freezed` should be recognized
3. **Check both methods**: Rule requires BOTH `fromJson` AND `toJson` (or annotation)
4. **Constructor vs method**: `fromJson` is typically a factory constructor, `toJson` is an instance method
5. **Abstract classes**: Abstract classes should not trigger warnings

## Guideline Alignment

This rule implements the guideline from the project architecture guidelines:

> "Separación estricta Domain/Data layer"
> "Serialización solo en data (Models)"

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
// lib/data/models/user_model.dart
@freezed
class UserModel with _$UserModel {
  const factory UserModel({required String id}) = _UserModel;
  // ❌ Missing fromJson
}
```

## Why Warning Instead of Error?

This rule uses `warning` severity (not `error`) because:

1. **False positives**: Some models may be used only for internal data structures (~20% estimated)
2. **Migration flexibility**: Existing codebases may have models without serialization for valid reasons
3. **Local-only models**: Some models may never interact with external APIs
4. **Gradual adoption**: Teams can fix warnings incrementally without blocking builds

For critical API models, developers should treat warnings as errors in practice.

## Related Rules

- `no_serialization_in_entities` - Prevents serialization in domain entities
- `domain_entities_must_use_freezed` - Enforces @freezed on domain entities
- `no_external_dependencies_in_domain` - Maintains clean architecture boundaries

## Implementation Notes

- Uses `ClassDeclaration` AST node visitor
- Checks for annotations: `@JsonSerializable`, `@jsonSerializable`, `@freezed`, `@Freezed`
- Verifies presence of both `fromJson` constructor AND `toJson` method
- Path-based filtering for data layer (`/data/models/`)
- Excludes abstract classes (no concrete serialization needed)
- Excludes private classes starting with `_`
- Inherits from `GeneratedSkippingDartLintRule` to skip generated files automatically
- Estimated false positive rate: < 20% (acceptable for warning level)

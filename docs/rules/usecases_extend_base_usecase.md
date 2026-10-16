<!-- example-scope: isolated usecases_extend_base_usecase -->

> **Example contract: `usecases_extend_base_usecase` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# usecases_extend_base_usecase

**Rule name**: `usecases_extend_base_usecase`
**Type**: Error
**Severity**: 🔴 Critical

## Overview

Enforces that all UseCases extend `BaseUseCase<T, P>` for consistent error handling and automatic conversion to `Result<T>`. This ensures centralized try-catch logic and prevents exceptions from escaping the domain layer.

## Rationale

UseCases are the entry points to business logic and must handle errors consistently. By extending `BaseUseCase`, you get:

1. **Centralized error handling**: `executeGuard()` wraps operations with try-catch
2. **AppException conversion**: Automatic wrapping of unexpected errors
3. **Result<T> guarantee**: UseCases never throw; always return `Result<T>`
4. **Consistency**: All UseCases follow the same error handling pattern

Without this enforcement, developers might:
- Duplicate try-catch logic across UseCases
- Handle errors inconsistently
- Allow exceptions to escape the domain layer
- Forget to convert errors to `Result<T>`

## ❌ Bad (will trigger the rule)

```dart
// lib/domain/useCases/get_user_use_case.dart
class GetUserUseCase {
  final UserRepository _repo;
  GetUserUseCase(this._repo);

  Future<Result<User>> execute(String id) async {
    try {
      return await _repo.getById(id);
    } catch (e) {
      return Failure(UnexpectedException('Error: $e'));
    }
  }
}

// lib/domain/useCases/create_product_use_case.dart
class CreateProductUseCase {
  final ProductRepository _repo;
  CreateProductUseCase(this._repo);

  // ❌ Even worse: throwing exceptions
  Future<Result<Product>> execute(ProductParams params) async {
    if (params.name.isEmpty) {
      throw ValidationException('Name required');
    }
    return await _repo.create(params.toEntity());
  }
}
```

## ✅ Good (will not trigger the rule)

```dart
// lib/domain/useCases/get_user_use_case.dart
class GetUserUseCase extends BaseUseCase<User, String> {
  final UserRepository _repo;
  GetUserUseCase(this._repo);

  @override
  Future<Result<User>> execute(String id) async {
    return executeGuard(() => _repo.getById(id));
  }
}

// lib/domain/useCases/create_product_use_case.dart
class CreateProductParams {
  final String name;
  final double price;
  const CreateProductParams({required this.name, required this.price});
}

class CreateProductUseCase extends BaseUseCase<Product, CreateProductParams> {
  final ProductRepository _repo;
  final Clock _clock;
  CreateProductUseCase(this._repo, this._clock);

  @override
  Future<Result<Product>> execute(CreateProductParams params) async {
    // Validation returns Failure, doesn't throw
    if (params.name.trim().isEmpty) {
      return const Failure(ValidationException('Product name required'));
    }

    final product = Product(
      id: null,
      name: params.name.trim(),
      price: params.price,
      createdAt: _clock.now(),
    );

    // executeGuard wraps the operation that might fail
    return executeGuard(() => _repo.create(product), context: 'CreateProductUseCase');
  }
}

// lib/domain/useCases/delete_user_use_case.dart
class DeleteUserUseCase extends BaseUseCase<void, String> {
  final UserRepository _repo;
  DeleteUserUseCase(this._repo);

  @override
  Future<Result<void>> execute(String id) async {
    return executeGuard(() => _repo.delete(id));
  }
}
```

## Exception Cases

The rule does **NOT** apply to:

1. **Abstract base classes**: Like `BaseUseCase` itself or custom base classes
   ```dart
   abstract class BaseUseCase<T, P> {
     Future<Result<T>> execute(P params);
   }
   ```

2. **Helper classes**: Classes that don't end with "UseCase"
   ```dart
   class UserParams {
     final String name;
     const UserParams(this.name);
   }
   ```

3. **Private classes**: Classes starting with `_` (usually internal implementations)

4. **Files outside domain/useCases/**: Only applies to `lib/domain/useCases/` directory

## Problem Message

> Los UseCases deben extender BaseUseCase<T, P> para manejo consistente de errores y conversión a Result<T>.

## Correction Message

> Extiende BaseUseCase<TipoRetorno, TipoParams> y usa executeGuard(() => ...) para envolver operaciones que puedan fallar.
> Ejemplo:
>   class GetUserUseCase extends BaseUseCase<User, String> {
>     final UserRepository _repo;
>     GetUserUseCase(this._repo);
>     @override
>     Future<Result<User>> execute(String id) async {
>       return executeGuard(() => _repo.getById(id));
>     }
>   }

## How to Test This Rule

### Setup Test Project

1. Navigate to a separate Flutter project that consumes this package
2. Ensure `dart_architecture_lints` is added as dependency
3. Add rule to `analysis_options.yaml`:
   ```yaml
   custom_lint:
     rules:
       usecases_extend_base_usecase: error
   ```

### Test Cases

**File: `lib/domain/useCases/test_get_user_use_case.dart`**
```dart
// ❌ Should trigger the rule (no extends clause)
class GetUserUseCase {
  final UserRepository _repo;
  GetUserUseCase(this._repo);

  Future<Result<User>> execute(String id) async {
    return await _repo.getById(id);
  }
}
```

**File: `lib/domain/useCases/test_create_user_use_case.dart`**
```dart
// ✅ Should NOT trigger (extends BaseUseCase)
class CreateUserUseCase extends BaseUseCase<User, String> {
  final UserRepository _repo;
  CreateUserUseCase(this._repo);

  @override
  Future<Result<User>> execute(String name) async {
    return executeGuard(() => _repo.create(User(name: name)));
  }
}
```

**File: `lib/domain/useCases/test_user_params.dart`**
```dart
// ✅ Should NOT trigger (doesn't end with UseCase)
class UserParams {
  final String name;
  const UserParams(this.name);
}
```

**File: `lib/domain/useCases/base_use_case.dart`**
```dart
// ✅ Should NOT trigger (abstract class)
abstract class BaseUseCase<T, P> {
  Future<Result<T>> execute(P params);
}
```

**File: `lib/presentation/controllers/user_controller.dart`**
```dart
// ✅ Should NOT trigger (not in domain/useCases/)
class UserController {
  Future<void> loadUser() async {
    // controller logic
  }
}
```

### Expected Results

Run `dart run custom_lint` and verify:
- ❌ 1 error in `test_get_user_use_case.dart`
- ✅ 0 errors in `test_create_user_use_case.dart` (extends BaseUseCase)
- ✅ 0 errors in `test_user_params.dart` (not a UseCase)
- ✅ 0 errors in `base_use_case.dart` (abstract class)
- ✅ 0 errors in `user_controller.dart` (not in domain/useCases/)

### Troubleshooting

If the rule doesn't work as expected:

1. **Check path detection**: Rule only applies to `lib/domain/useCases/` (case-sensitive)
2. **Verify class name**: Must end with "UseCase" (case-sensitive)
3. **Check abstract classes**: Abstract classes should be excluded
4. **Verify extends clause**: Must extend exactly `BaseUseCase` (not subclasses)

## Guideline Alignment

This rule directly implements the guideline from the project architecture guidelines:

> "BaseUseCase Pattern (OBLIGATORIO)"

The guideline states:

> "UseCases **nunca** lanzan excepciones; **siempre** devuelven `Result<T>`"

**BaseUseCase definition (from guideline)**:
```dart
abstract class BaseUseCase<T, P> {
  const BaseUseCase();
  Future<Result<T>> execute(P params);

  @protected
  Future<Result<TOut>> executeGuard<TOut>(
    Future<Result<TOut>> Function() action, {
    String? context,
  }) async {
    try {
      return await action();
    } on AppException catch (e) {
      return Failure(e);
    } catch (e, stack) {
      return Failure(
        UnexpectedException(context ?? 'UseCase execution failed',
            originalException: e, stackTrace: stack),
      );
    }
  }
}
```

**✅ CORRECTO**:
```dart
class GetUserUseCase extends BaseUseCase<User, String> {
  final UserRepository _repo;
  GetUserUseCase(this._repo);

  @override
  Future<Result<User>> execute(String id) async {
    return executeGuard(() => _repo.getById(id));
  }
}
```

**❌ INCORRECTO**:
```dart
class GetUserUseCase {
  Future<Result<User>> execute(String id) async {
    try {
      return await _repo.getById(id);
    } catch (e) {
      return Failure(UnexpectedException('Error: $e'));
    }
  }
}
```

## Related Rules

- `usecases_follow_pattern` - Enforces `execute()` method returning `Result<T>`
- `no_result_throw` - Prevents throwing when Result<T> is expected
- `repository_methods_return_result` - Enforces Result<T> in repositories
- `no_external_dependencies_in_domain` - Maintains clean architecture boundaries

## Implementation Notes

- Uses `ClassDeclaration` AST node visitor
- Checks for `extends` clause with superclass name `BaseUseCase`
- Path-based filtering for domain layer (`/domain/useCases/`)
- Class name must end with "UseCase"
- Excludes abstract classes (no implementation required)
- Excludes private classes starting with `_`
- Inherits from `GeneratedSkippingDartLintRule` to skip generated files automatically

## Estimated False Positives

**< 10%** - Very low false positives expected:
- Only applies to classes named `*UseCase` in `domain/useCases/`
- Clear naming convention makes detection accurate
- Abstract base classes are properly excluded

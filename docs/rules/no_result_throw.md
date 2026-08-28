# no_result_throw

**Rule name**: `no_result_throw`
**Type**: Critical (error)

## Overview

Prohibits `throw` statements in UseCases and Repositories. These classes must return `Result<T>` for all errors, not throw exceptions. Exception: Re-throw in catch blocks is allowed for controlled error propagation.

## Rationale

When UseCases/Repositories throw exceptions instead of returning `Result<T>`:

1. **Breaks Result contract**: Caller expects `Result<Success|Failure>`, not exceptions
2. **Untyped errors**: Exceptions lack structured error information (code, message, type)
3. **Catch-all handling**: Forces generic `try-catch` instead of pattern matching on Result
4. **Lost context**: Exception stack traces harder to track than structured AppException
5. **Inconsistent API**: Some methods return Result, others throw - confusing interface

All errors must be wrapped in `Failure(AppException(...))` for consistent, type-safe error handling.

## ❌ Bad (will trigger the rule)

```dart
// ❌ CRITICAL ERROR - UseCase throwing exceptions
class GetExpedientesUseCase extends BaseUseCase<List<Expediente>, NoParams> {
  @override
  Future<Result<List<Expediente>>> execute(NoParams params) async {
    if (params.someCondition) {
      throw Exception('Invalid parameters!'); // ❌ Breaks Result contract
    }

    final data = await repository.getExpedientes();

    if (data.isEmpty) {
      throw StateError('No expedientes found'); // ❌ Untyped error
    }

    return Success(data);
  }
}

// ❌ CRITICAL ERROR - Repository throwing exceptions
class ExpedienteRepositoryImpl implements ExpedienteRepository {
  @override
  Future<Result<List<Expediente>>> getExpedientes() async {
    if (!await networkInfo.isConnected) {
      throw NetworkException('No internet'); // ❌ Should return Failure
    }

    try {
      final response = await apiClient.get('/expedientes');
      return Success(response.data);
    } on DioException catch (e) {
      throw ServerException(e.message); // ❌ Re-throwing as different exception
    }
  }
}

// Problems:
// - Caller can't pattern match on errors
// - Inconsistent error handling
// - Lost type safety
// - try-catch instead of when/map
```

## ✅ Good (will not trigger the rule)

```dart
// ✅ CORRECT - UseCase returns Failure instead of throwing
class GetExpedientesUseCase extends BaseUseCase<List<Expediente>, NoParams> {
  @override
  Future<Result<List<Expediente>>> execute(NoParams params) async {
    if (params.someCondition) {
      return Failure(
        AppException.validation(
          code: 'invalid_params',
          message: 'Los parámetros proporcionados no son válidos',
        ),
      );
    }

    final result = await repository.getExpedientes();

    return result.when(
      success: (data) {
        if (data.isEmpty) {
          return Failure(
            AppException.notFound(
              code: 'no_expedientes',
              message: 'No se encontraron expedientes',
            ),
          );
        }
        return Success(data);
      },
      failure: (error) => Failure(error), // Forward error
    );
  }
}

// ✅ CORRECT - Repository returns Failure
class ExpedienteRepositoryImpl implements ExpedienteRepository {
  @override
  Future<Result<List<Expediente>>> getExpedientes() async {
    if (!await networkInfo.isConnected) {
      return Failure(
        AppException.network(
          code: 'no_connection',
          message: 'No hay conexión a Internet',
        ),
      );
    }

    try {
      final response = await apiClient.get('/expedientes');
      final expedientes = (response.data as List)
          .map((json) => Expediente.fromJson(json))
          .toList();
      return Success(expedientes);
    } on DioException catch (e) {
      return Failure(
        AppException.server(
          code: 'dio_error',
          message: 'Error del servidor: ${e.message}',
          originalError: e,
        ),
      );
    } catch (e, stackTrace) {
      return Failure(
        AppException.unknown(
          code: 'unexpected_error',
          message: 'Error inesperado',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

// ✅ ALLOWED - Re-throw in catch for controlled propagation
class DataRepositoryImpl implements DataRepository {
  @override
  Future<Result<Data>> getData() async {
    try {
      final response = await apiClient.get('/data');
      return Success(response.data);
    } catch (e, stackTrace) {
      logger.error('Critical error', e, stackTrace);
      rethrow; // ✅ Re-throw in catch is allowed
    }
  }
}

// ✅ Clean error handling with pattern matching
class MyScreen extends StatelessWidget {
  void loadData() async {
    final result = await getExpedientesUseCase.execute(NoParams());

    result.when(
      success: (data) => print('Success: $data'),
      failure: (error) {
        // Type-safe error handling
        if (error.isNetwork) {
          print('Network error: ${error.message}');
        } else if (error.isValidation) {
          print('Validation error: ${error.message}');
        }
      },
    );
  }
}
```

## Exception Cases

**Allowed `throw` usage:**

1. **Re-throw in catch blocks**: For logging/monitoring before propagation
   ```dart
   try {
     // ...
   } catch (e) {
     logger.error('Error', e);
     rethrow; // ✅ Allowed
   }
   ```

2. **Not in UseCase/Repository**: Other classes can throw (but shouldn't in domain layer)

## Problem Message

> Do not throw exceptions in UseCase or Repository. Return Failure(AppException(...)) instead to maintain Result<T> contract.

## Correction Message

> Replace throw with: return Failure(AppException.validation(code: "...", message: "..."));

## How to Test This Rule

### Setup Test Project

1. Create a test project with this custom lint as dependency
2. Add rule to `analysis_options.yaml`:
   ```yaml
   custom_lint:
     rules:
       no_result_throw: error
   ```

### Test File: `lib/test_no_result_throw.dart`

```dart
import 'package:dartz/dartz.dart';

// ❌ Should trigger error
class BadUseCase {
  Future<Result<String>> execute() async {
    throw Exception('Error'); // Direct throw
  }
}

// ❌ Should trigger error
class BadRepository {
  Future<Result<int>> getData() async {
    if (someCondition) {
      throw StateError('Invalid state'); // Throw not in catch
    }
    return Success(42);
  }
}

// ❌ Should trigger error
class AnotherBadUseCase {
  Future<Result<bool>> call() async {
    try {
      return Success(true);
    } catch (e) {
      throw Exception('Error'); // Throw even in catch (not re-throw)
    }
  }
}

// ✅ Should NOT trigger - Returns Failure
class GoodUseCase {
  Future<Result<String>> execute() async {
    return Failure(AppException.validation(
      code: 'error',
      message: 'Error message',
    ));
  }
}

// ✅ Should NOT trigger - Re-throw is allowed
class GoodRepository {
  Future<Result<int>> getData() async {
    try {
      return Success(42);
    } catch (e) {
      logger.error('Error', e);
      rethrow; // Re-throw is allowed
    }
  }
}

// ✅ Should NOT trigger - Not a UseCase/Repository
class MyService {
  void doSomething() {
    throw Exception('This is fine'); // Not UseCase/Repository
  }
}
```

### Expected Results

```bash
$ dart run custom_lint

lib/test_no_result_throw.dart:6:5 • Do not throw exceptions in UseCase or Repository... • no_result_throw
lib/test_no_result_throw.dart:14:7 • Do not throw exceptions in UseCase or Repository... • no_result_throw
lib/test_no_result_throw.dart:25:7 • Do not throw exceptions in UseCase or Repository... • no_result_throw
```

## Related Guidelines

- 02A_RESULT_PATTERNS.md - Result<T> Pattern
- 01A_ARCHITECTURE.md - Domain Layer

## Benefits

- ✅ Type-safe error handling
- ✅ Consistent API contract
- ✅ Pattern matching on errors
- ✅ Structured error information
- ✅ Better error tracking

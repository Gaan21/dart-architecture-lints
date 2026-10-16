<!-- example-scope: isolated no_late_keyword -->

> **Example contract: `no_late_keyword` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_late_keyword

**Rule name**: `no_late_keyword`  
**Type**: Critical  

## Overview

Prohibits the use of the `late` keyword except for justified dependency injection cases. This enforces the guideline invariant: "Prohibido `!` (null-assert) y `late` salvo DI muy justificada. Preferir `final` e inmutabilidad."

## Rationale

The `late` keyword can lead to runtime errors if accessed before initialization and goes against the principle of preferring safe, immutable code. Using nullable types or proper constructor initialization is safer and more explicit.

## ❌ Bad (will trigger the rule)

```dart
class UserProfile {
  late String name;           // ❌ Use nullable or constructor param
  late int _counter;          // ❌ Initialize in constructor 
  late final List<String> items; // ❌ Initialize in constructor
  
  void initializeProfile() {
    name = 'John';
    _counter = 0;
    items = [];
  }
}

class DataManager {
  late HttpClient client;     // ❌ Use nullable or inject via constructor
}
```

## ✅ Good (will not trigger the rule)

```dart
// Preferred: nullable types
class UserProfile {
  String? name;              // ✅ Nullable is explicit
  int _counter = 0;          // ✅ Default value
  final List<String> items;  // ✅ Constructor parameter
  
  UserProfile({this.name, this.items = const []});
}

// Preferred: constructor injection
class DataManager {
  final HttpClient client;   // ✅ Injected via constructor
  
  DataManager(this.client);
}

// Justified DI cases (exceptions to the rule)
class ServiceContainer {
  late final GetIt instance;        // ✅ DI framework type
  late final ServiceLocator locator; // ✅ DI framework type
}

class DIContainer {
  late final Container container;    // ✅ In DI-related class
}

class AppLocator {
  late final Injector injector;     // ✅ In DI-related class
}
```

## Exception Cases

The rule allows `late final` in these specific cases:

1. **DI Framework Types**: When the type name suggests dependency injection
   - `GetIt`, `Locator`, `ServiceLocator`, `Container`, `Injector`, `Provider`, `Resolver`

2. **DI Container Classes**: When the class name suggests it's a DI container
   - Class names containing: `Container`, `Locator`, `Injector`, `ServiceContainer`, `DependencyContainer`, `DI`

3. **Must be `late final`**: The combination `late final` is required for justification (not just `late`)

## Problem Message

> Avoid using the "late" keyword. Use nullable types or initialize in constructor instead.

## Correction Message

> Consider using nullable types (Type?) or initializing the variable in the constructor.

## How to Test This Rule

### Setup Test Project

1. Create a test project with this custom lint as dependency
2. Add rule to `analysis_options.yaml`:
   ```yaml
   custom_lint:
     rules:
       no_late_keyword: true
   ```

### Test Cases

**File: `lib/test_late_keyword.dart`**
```dart
// Test cases that SHOULD trigger the rule
class BadExamples {
  late String name;                    // ❌ Should trigger
  late int _counter;                   // ❌ Should trigger  
  late final List<String> items;      // ❌ Should trigger
  late HttpClient client;             // ❌ Should trigger
}

// Test cases that should NOT trigger the rule
class GoodExamples {
  String? name;                        // ✅ Should pass
  int _counter = 0;                    // ✅ Should pass
  final List<String> items;            // ✅ Should pass
  
  GoodExamples({this.name, this.items = const []});
}

// Exception cases that should NOT trigger
class ServiceContainer {
  late final GetIt getIt;             // ✅ Should pass (DI type)
  late final ServiceLocator locator;  // ✅ Should pass (DI type)
}

class DIContainer {
  late final Container container;     // ✅ Should pass (DI class)
}
```

### Expected Results

Run `dart run custom_lint` and verify:
- 4 lint errors in `BadExamples` class
- 0 lint errors in `GoodExamples` class  
- 0 lint errors in `ServiceContainer` and `DIContainer` classes

### Troubleshooting

If the rule doesn't work as expected:

1. **Check syntax**: Ensure no compilation errors in the lint rule code
2. **Verify registration**: Confirm rule is added to plugin's `getLintRules()` method
3. **Test DI detection**: The rule should only allow `late final` with recognized DI types/classes
4. **Check messages**: Error should appear on the `late` keyword specifically

## Related Rules

- `no_bang_operator` - Also enforces safety by prohibiting null assertion operator
- Built-in Dart analyzer rules for late variable usage

## Implementation Notes

- Uses `VariableDeclarationList` AST node visitor to detect `late` keyword
- Checks for `late final` combination for DI justification
- Pattern matches on type names and class names for DI detection  
- Reports lint error specifically on the `late` token for precise error location

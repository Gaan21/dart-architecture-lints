# enforce_final_variables

**Rule name**: `enforce_final_variables`  
**Type**: Critical  

## Overview

Enforces the use of `final` instead of `var` for variables that are not reassigned. This implements the guideline: "No usar 'var' (salvo casos locales inmutables muy evidentes)" and promotes immutability as specified in the core guidelines.

## Rationale

Using `final` over `var` makes immutability explicit and prevents accidental reassignment. This leads to safer, more predictable code and aligns with functional programming principles emphasized in the guidelines.

## ❌ Bad (will trigger the rule)

```dart
class UserService {
  var userName = 'John';        // ❌ Use final instead
  var userList = <User>[];      // ❌ Use final instead
}

void processUser() {
  var name = 'Jane';            // ❌ Use final instead
  var age = 25;                 // ❌ Use final instead
  var isActive = true;          // ❌ Use final instead
  
  print('$name is $age years old');
}

void calculateTotal() {
  var price = 100.0;            // ❌ Use final instead
  var tax = price * 0.1;        // ❌ Use final instead
  var total = price + tax;      // ❌ Use final instead
}
```

## ✅ Good (will not trigger the rule)

```dart
class UserService {
  final String userName = 'John';     // ✅ Immutability explicit
  final List<User> userList = [];     // ✅ Immutability explicit
}

void processUser() {
  final String name = 'Jane';         // ✅ Cannot be reassigned
  final int age = 25;                 // ✅ Type and immutability clear
  final bool isActive = true;         // ✅ Explicit final
  
  print('$name is $age years old');
}

void calculateTotal() {
  final double price = 100.0;         // ✅ Immutable
  final double tax = price * 0.1;     // ✅ Immutable
  final double total = price + tax;   // ✅ Immutable
}

// Acceptable var usage (exceptions)
void processItems() {
  for (var i = 0; i < 10; i++) {     // ✅ Loop variable - var acceptable
    print(i);
  }
  
  for (var item in items) {           // ✅ For-in loop - var acceptable
    print(item);
  }
}
```

## Exception Cases

The rule allows `var` in these specific contexts:

1. **For loop declarations**: `for (var i = 0; i < 10; i++)`
2. **Enhanced for loops (for-in)**: `for (var item in items)`

These are considered "casos locales inmutables muy evidentes" where the loop variable scope and usage is clear.

## Problem Message

> Use "final" instead of "var" for variables that are not reassigned.

## Correction Message

> Replace "var" with "final" to make immutability explicit.

## How to Test This Rule

### Setup Test Project

1. Create a test project with this custom lint as dependency
2. Add rule to `analysis_options.yaml`:
   ```yaml
   custom_lint:
     rules:
       enforce_final_variables: true
   ```

### Test Cases

**File: `lib/test_final_variables.dart`**
```dart
// Test cases that SHOULD trigger the rule
class BadExamples {
  var userName = 'John';               // ❌ Should trigger
  var count = 0;                       // ❌ Should trigger
  var items = <String>[];              // ❌ Should trigger
  
  void method() {
    var localVar = 'test';             // ❌ Should trigger
    var number = 42;                   // ❌ Should trigger
    var flag = false;                  // ❌ Should trigger
  }
}

// Test cases that should NOT trigger the rule
class GoodExamples {
  final String userName = 'John';      // ✅ Should pass
  final int count = 0;                 // ✅ Should pass
  final List<String> items = [];       // ✅ Should pass
  
  void method() {
    final String localVar = 'test';    // ✅ Should pass
    final int number = 42;             // ✅ Should pass
    final bool flag = false;           // ✅ Should pass
    
    // Loop exceptions - should NOT trigger
    for (var i = 0; i < 10; i++) {    // ✅ Should pass
      print(i);
    }
    
    for (var item in items) {          // ✅ Should pass
      print(item);
    }
  }
}
```

### Expected Results

Run `dart run custom_lint` and verify:
- 6 lint errors in `BadExamples` class (3 fields + 3 local variables)
- 0 lint errors in `GoodExamples` class
- Loop variables with `var` should not trigger errors

### Troubleshooting

If the rule doesn't work as expected:

1. **Check syntax**: Ensure no compilation errors in the lint rule code
2. **Verify registration**: Confirm rule is added to plugin's `getLintRules()` method
3. **Test loop detection**: Loop variables should be exempt from the rule
4. **Check error location**: Error should appear specifically on the `var` keyword

## Guideline Alignment

This rule directly implements the guideline from the project architecture guidelines:

**✅ CORRECTO**:
```dart
final String nombre = 'Juan';
const int maxRetries = 3;
final List<User> userList = [];
```

**❌ INCORRECTO**:
```dart
var nombre = 'Juan';           // No usar 'var' (salvo casos locales inmutables muy evidentes)
```

## Related Rules

- `no_late_keyword` - Also promotes immutability by restricting `late`
- Built-in Dart `prefer_final_locals` - Similar but applies only to local variables
- Built-in Dart `prefer_final_fields` - Similar but applies only to instance fields

## Implementation Notes

- Uses `VariableDeclarationList` AST node visitor to detect `var` keyword
- Checks context to allow `var` in for-loops and for-in loops
- Reports lint error specifically on the `var` token for precise error location
- Does not attempt complex reassignment analysis - prefers explicit immutability
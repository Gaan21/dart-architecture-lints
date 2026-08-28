# viewmodels_no_flutter_types

**Rule name**: `viewmodels_no_flutter_types`
**Type**: Critical (error)

## Overview

Prevents ViewModels from using Flutter-specific types (TextEditingController, FocusNode, GlobalKey, Color, etc.). ViewModels should be UI-agnostic for better testability without `flutter_test`.

## Rationale

When ViewModels contain Flutter types:

1. **Testing requires flutter_test**: Can't use simple Dart unit tests
2. **Tight coupling**: ViewModel coupled to Flutter framework
3. **Harder to port**: Can't reuse logic in other platforms (web, CLI, etc.)
4. **Architectural violation**: ViewModel should be pure business logic

Flutter types belong in `UiState` classes that are specifically designed for UI state management.

## ❌ Bad (will trigger the rule)

```dart
// ❌ CRITICAL ERROR - ViewModel with Flutter types
class ExpedienteListViewModel extends BaseViewModel {
  final TextEditingController _searchController = TextEditingController(); // Flutter type!
  final FocusNode _searchFocus = FocusNode(); // Flutter type!
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(); // Flutter type!

  Color get statusColor => _isActive ? Colors.green : Colors.red; // Flutter type!

  void searchExpedientes(String query) {
    final text = _searchController.text; // Coupled to Flutter
    // ...
  }

  @override
  void dispose() {
    _searchController.dispose(); // Must remember to dispose
    _searchFocus.dispose();
    super.dispose();
  }
}

// Problems:
// - Can't test without flutter_test
// - Tightly coupled to Flutter
// - Controllers in wrong layer
// - Disposal responsibilities in ViewModel
```

## ✅ Good (will not trigger the rule)

```dart
// ✅ CORRECT - ViewModel is UI-agnostic (pure Dart)
class ExpedienteListViewModel extends BaseViewModel {
  String _searchQuery = ''; // Plain Dart type
  List<Expediente> _expedientes = [];
  bool _isActive = true;

  String get searchQuery => _searchQuery;
  List<Expediente> get expedientes => _expedientes;
  String get statusMessage => _isActive ? 'Activo' : 'Inactivo'; // String, not Color

  void searchExpedientes(String query) {
    _searchQuery = query;
    // Business logic using plain Dart types
    _expedientes = repository.search(query);
    notifyListeners();
  }

  // No dispose needed - no Flutter resources!
}

// ✅ CORRECT - Flutter types in UiState
class SearchUiState extends ChangeNotifier {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  TextEditingController get searchController => _searchController;
  FocusNode get searchFocus => _searchFocus;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
}

// ✅ CORRECT - Screen coordinates both
class ExpedienteListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SearchUiState()), // Flutter state
        ChangeNotifierProvider(create: (_) => ExpedienteListViewModel()), // Business logic
      ],
      child: const _ExpedienteListScreenContent(),
    );
  }
}

class _ExpedienteListScreenContent extends StatelessWidget {
  const _ExpedienteListScreenContent();

  @override
  Widget build(BuildContext context) {
    final uiState = context.watch<SearchUiState>();
    final viewModel = context.watch<ExpedienteListViewModel>();

    return TextField(
      controller: uiState.searchController, // From UiState
      focusNode: uiState.searchFocus, // From UiState
      onChanged: (value) => viewModel.searchExpedientes(value), // To ViewModel
    );
  }
}

// Testing is easy - pure Dart:
void main() {
  test('searchExpedientes filters correctly', () {
    final viewModel = ExpedienteListViewModel();
    viewModel.searchExpedientes('test');
    expect(viewModel.searchQuery, 'test');
    // No flutter_test needed!
  });
}
```

## Detected Flutter Types

This rule detects ViewModels with these field types:

**Controllers:**
- `TextEditingController`
- `ScrollController`
- `AnimationController`
- `TabController`
- `PageController`

**UI Elements:**
- `FocusNode`
- `GlobalKey`

**Styling:**
- `Color`
- `TextStyle`
- `EdgeInsets`
- `BorderRadius`
- `BoxDecoration`

**Widgets:**
- `Widget`
- `StatelessWidget`
- `StatefulWidget`

**Note**: `BuildContext` is already covered by the `viewmodels_no_buildcontext` rule.

## Problem Message

> ViewModel should not use Flutter types (TextEditingController, FocusNode, GlobalKey, etc.). This couples ViewModel to Flutter and makes testing difficult.

## Correction Message

> Move Flutter types to UiState class. ViewModel should be UI-agnostic and testable without flutter_test.

## How to Test This Rule

### Setup Test Project

1. Create a test project with this custom lint as dependency
2. Add rule to `analysis_options.yaml`:
   ```yaml
   custom_lint:
     rules:
       viewmodels_no_flutter_types: error
   ```

### Test File: `lib/test_viewmodels_no_flutter_types.dart`

```dart
import 'package:flutter/material.dart';

// ❌ Should trigger error - TextEditingController
class BadViewModel1 extends ChangeNotifier {
  final TextEditingController _controller = TextEditingController();
}

// ❌ Should trigger error - FocusNode
class BadViewModel2 extends ChangeNotifier {
  final FocusNode _focus = FocusNode();
}

// ❌ Should trigger error - GlobalKey
class BadViewModel3 extends ChangeNotifier {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
}

// ❌ Should trigger error - Color
class BadViewModel4 extends ChangeNotifier {
  Color statusColor = Colors.green;
}

// ❌ Should trigger error - ScrollController
class BadViewModel5 extends ChangeNotifier {
  final ScrollController _scrollController = ScrollController();
}

// ✅ Should NOT trigger - Plain Dart types
class GoodViewModel extends ChangeNotifier {
  String _query = '';
  int _count = 0;
  List<String> _items = [];
  bool _isLoading = false;

  String get query => _query;
  int get count => _count;
  List<String> get items => _items;
  bool get isLoading => _isLoading;
}

// ✅ Should NOT trigger - Flutter types in UiState (not ViewModel)
class SearchUiState extends ChangeNotifier {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }
}

// ✅ Should NOT trigger - Not a ViewModel
class MyService {
  final TextEditingController _controller = TextEditingController();
}
```

### Expected Results

```bash
$ dart run custom_lint

lib/test_viewmodels_no_flutter_types.dart:5:3 • ViewModel should not use Flutter types... • viewmodels_no_flutter_types
lib/test_viewmodels_no_flutter_types.dart:10:3 • ViewModel should not use Flutter types... • viewmodels_no_flutter_types
lib/test_viewmodels_no_flutter_types.dart:15:3 • ViewModel should not use Flutter types... • viewmodels_no_flutter_types
lib/test_viewmodels_no_flutter_types.dart:20:3 • ViewModel should not use Flutter types... • viewmodels_no_flutter_types
lib/test_viewmodels_no_flutter_types.dart:25:3 • ViewModel should not use Flutter types... • viewmodels_no_flutter_types
```

## Related Guidelines

- 02B_UI_PATTERNS.md - ViewModel Pattern
- 02B_UI_SCREENS_COMPLEX.md - UiState Pattern
- 04A_UNIT_TESTING_VIEWMODELS.md

## Benefits

- ✅ ViewModels testable with pure Dart tests
- ✅ No flutter_test dependency for business logic
- ✅ Clear separation: UiState = Flutter, ViewModel = Logic
- ✅ Better portability
- ✅ Faster test execution

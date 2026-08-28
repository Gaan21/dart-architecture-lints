# mixin_no_state_ownership

**Rule name**: `mixin_no_state_ownership`
**Type**: Critical (error)

## Overview

Prevents mixins from owning resources with lifecycle (TextEditingController, Timer, FocusNode, ScrollController, etc.). Mixins should be stateless and only provide behavior, not own stateful resources that require disposal.

## Rationale

When mixins own lifecycle resources:

1. **Unclear ownership**: Who is responsible for disposing the resource?
2. **Memory leaks**: Resources in mixins often aren't disposed properly
3. **Architectural violation**: Mixins should provide behavior, not state
4. **Testing difficulties**: Can't easily test resource cleanup

The correct pattern is to own resources in a `ChangeNotifier` (UiState) and access them via `BuildContext` in mixin methods.

## ❌ Bad (will trigger the rule)

```dart
// ❌ CRITICAL ERROR - Mixin owning TextEditingController
mixin AppBarActionsMixin {
  final TextEditingController _searchController = TextEditingController();

  void search() {
    final query = _searchController.text;
    // Perform search
  }

  // Problem: Who calls dispose()? When?
}

// ❌ CRITICAL ERROR - Mixin owning Timer
mixin SearchDebounceMixin {
  Timer? _debounceTimer;

  void debounceSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      // Search
    });
  }
  // Problem: Timer never cancelled properly
}

// ❌ CRITICAL ERROR - Mixin owning FocusNode
mixin FocusManagementMixin {
  final FocusNode _focusNode = FocusNode();

  void requestFocus() {
    _focusNode.requestFocus();
  }
  // Problem: FocusNode never disposed
}

// ❌ CRITICAL ERROR - Other lifecycle resources
mixin ScrollMixin {
  final ScrollController _scrollController = ScrollController();
}

mixin AnimationMixin {
  late AnimationController _animationController;
}
```

## ✅ Good (will not trigger the rule)

```dart
// ✅ CORRECT - UiState owns the resource
class SearchUiState extends ChangeNotifier {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  TextEditingController get searchController => _searchController;

  void setQuery(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      // Perform search
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// ✅ CORRECT - Mixin accesses resource via BuildContext
mixin AppBarActionsMixin {
  void search(BuildContext context) {
    final uiState = context.read<SearchUiState>();
    final query = uiState.searchController.text;
    // Perform search
  }

  void clearSearch(BuildContext context) {
    context.read<SearchUiState>().searchController.clear();
  }
}

// ✅ CORRECT - Mixin with stateless behavior only
mixin ValidationMixin {
  bool validateEmail(String email) {
    return email.contains('@');
  }

  String? getErrorMessage(String? value) {
    if (value == null || value.isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }
}

// ✅ CORRECT - Mixin with primitive/data fields (no lifecycle)
mixin ConfigMixin {
  final String defaultTitle = 'Mi App';
  final int maxRetries = 3;
}

// ✅ CORRECT - Screen provides scoped UiState via Provider
class ExpedienteListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SearchUiState()),
        ChangeNotifierProvider(create: (_) => ExpedienteListViewModel()),
      ],
      child: const _ExpedienteListScreenContent(),
    );
  }
}
```

## Detected Types

This rule detects mixin fields with these types:

- `TextEditingController`
- `ScrollController`
- `AnimationController`
- `TabController`
- `PageController`
- `FocusNode`
- `Timer`
- `StreamController`
- `StreamSubscription`
- `VideoPlayerController`
- `CameraController`

## Problem Message

> Mixin should not own resources with lifecycle (TextEditingController, Timer, FocusNode, etc.). Mixins must be stateless and only provide behavior.

## Correction Message

> Move resource ownership to a ChangeNotifier (UiState) and access it via BuildContext + Provider in the mixin methods.

## How to Test This Rule

### Setup Test Project

1. Create a test project with this custom lint as dependency
2. Add rule to `analysis_options.yaml`:
   ```yaml
   custom_lint:
     rules:
       mixin_no_state_ownership: error
   ```

### Test File: `lib/test_mixin_no_state_ownership.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';

// ❌ Should trigger error
mixin BadAppBarMixin {
  final TextEditingController _searchController = TextEditingController();
}

// ❌ Should trigger error
mixin BadSearchMixin {
  Timer? _debounceTimer;
}

// ❌ Should trigger error
mixin BadFocusMixin {
  final FocusNode _focusNode = FocusNode();
}

// ❌ Should trigger error
mixin BadScrollMixin {
  final ScrollController _scrollController = ScrollController();
}

// ✅ Should NOT trigger (stateless behavior only)
mixin GoodValidationMixin {
  bool validateEmail(String email) => email.contains('@');
}

// ✅ Should NOT trigger (primitive fields)
mixin GoodConfigMixin {
  final String title = 'App';
  final int maxRetries = 3;
}

// ✅ Should NOT trigger (accesses via BuildContext)
mixin GoodAppBarMixin {
  void search(BuildContext context) {
    final controller = context.read<SearchUiState>().searchController;
    // Use controller
  }
}

// ✅ Correct pattern: UiState owns resources
class SearchUiState extends ChangeNotifier {
  final TextEditingController _searchController = TextEditingController();

  TextEditingController get searchController => _searchController;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
```

### Expected Results

```bash
$ dart run custom_lint

lib/test_mixin_no_state_ownership.dart:5:3 • Mixin should not own resources with lifecycle... • mixin_no_state_ownership
lib/test_mixin_no_state_ownership.dart:10:3 • Mixin should not own resources with lifecycle... • mixin_no_state_ownership
lib/test_mixin_no_state_ownership.dart:15:3 • Mixin should not own resources with lifecycle... • mixin_no_state_ownership
lib/test_mixin_no_state_ownership.dart:20:3 • Mixin should not own resources with lifecycle... • mixin_no_state_ownership
```

## Related Guidelines

- 02B_UI_SCREENS_COMPLEX.md - Provider Scoped Pattern
- 02B_UI_PATTERNS.md - UiState Pattern

## Benefits

- ✅ Prevents memory leaks
- ✅ Clear lifecycle ownership
- ✅ Better testability
- ✅ Enforces architectural patterns
- ✅ Explicit resource management

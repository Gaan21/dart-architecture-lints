# no_static_map_controllers

**Rule name**: `no_static_map_controllers`
**Type**: Critical (error)

## Overview

Prohibits static Map fields that contain Flutter controllers or resources with lifecycle (TextEditingController, Timer, FocusNode, ScrollController, etc.). This enforces proper lifecycle management and prevents memory leaks.

## Rationale

Static Maps containing controllers create several critical problems:

1. **Memory leaks**: Resources stored in static Maps are never disposed, remaining in memory forever
2. **Key collisions**: Multiple screens using the same Type as key can interfere with each other
3. **Implicit lifecycle**: No clear ownership - unclear when resources should be created/disposed
4. **Testing difficulties**: Static state makes unit testing and widget testing unreliable

## ❌ Bad (will trigger the rule)

```dart
// ❌ CRITICAL ERROR - Static Map with TextEditingController
class AppBarActionsMixin {
  static final Map<Type, TextEditingController> _controllers = {};

  TextEditingController getController(Type screenType) {
    return _controllers.putIfAbsent(
      screenType,
      () => TextEditingController(), // Never disposed!
    );
  }
}

// ❌ CRITICAL ERROR - Static Map with Timer
class SearchHelper {
  static final Map<String, Timer> _debounceTimers = {};
}

// ❌ CRITICAL ERROR - Static Map with FocusNode
class FocusManager {
  static final Map<String, FocusNode> _focusNodes = {};
}

// ❌ CRITICAL ERROR - Other lifecycle resources
class UIResources {
  static final Map<int, ScrollController> _scrollControllers = {};
  static final Map<String, AnimationController> _animations = {};
  static final Map<Type, StreamController> _streams = {};
}
```

## ✅ Good (will not trigger the rule)

```dart
// ✅ CORRECT - Controllers in scoped UiState with Provider
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

// ✅ CORRECT - Provide scoped instance per screen
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

// ✅ CORRECT - Access via Provider in mixin
mixin AppBarActionsMixin {
  void search(BuildContext context) {
    final controller = context.read<SearchUiState>().searchController;
    // Use controller
  }
}

// ✅ OK - Static Map without lifecycle resources (primitives/data)
class ConfigCache {
  static final Map<String, String> _settings = {};
  static final Map<int, UserData> _userData = {}; // Plain data class
}
```

## Detected Types

This rule detects static Maps with these value types:

- `TextEditingController`
- `ScrollController`
- `AnimationController`
- `TabController`
- `PageController`
- `FocusNode`
- `Timer`
- `StreamController`
- `StreamSubscription`

## Problem Message

> Static Map containing controllers/resources with lifecycle (TextEditingController, Timer, FocusNode, etc.) causes memory leaks and lifecycle issues.

## Correction Message

> Move controllers to a scoped ChangeNotifier (UiState) managed by Provider. Controllers must be properly disposed when no longer needed.

## How to Test This Rule

### Setup Test Project

1. Create a test project with this custom lint as dependency
2. Add rule to `analysis_options.yaml`:
   ```yaml
   custom_lint:
     rules:
       no_static_map_controllers: error
   ```

### Test File: `lib/test_static_map_controllers.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';

// ❌ Should trigger error
class BadAppBarMixin {
  static final Map<Type, TextEditingController> _controllers = {};
}

// ❌ Should trigger error
class BadSearchHelper {
  static final Map<String, Timer> _timers = {};
}

// ❌ Should trigger error
class BadFocusManager {
  static final Map<int, FocusNode> _nodes = {};
}

// ✅ Should NOT trigger (proper scoped UiState)
class SearchUiState extends ChangeNotifier {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ✅ Should NOT trigger (non-lifecycle data)
class ConfigCache {
  static final Map<String, String> _settings = {};
}
```

### Expected Results

```bash
$ dart run custom_lint

lib/test_static_map_controllers.dart:5:3 • Static Map containing controllers/resources with lifecycle... • no_static_map_controllers
lib/test_static_map_controllers.dart:10:3 • Static Map containing controllers/resources with lifecycle... • no_static_map_controllers
lib/test_static_map_controllers.dart:15:3 • Static Map containing controllers/resources with lifecycle... • no_static_map_controllers
```

## Related Guidelines

- 02B_UI_SCREENS_COMPLEX.md - Provider Scoped Pattern
- 02B_UI_PATTERNS.md - UiState Pattern

## Benefits

- ✅ Prevents memory leaks
- ✅ Clear lifecycle ownership
- ✅ Better testability
- ✅ Explicit resource management
- ✅ No key collision bugs

<!-- example-scope: isolated top_level_screens_must_use_base_contract -->

> **Example contract: `top_level_screens_must_use_base_contract` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# top_level_screens_must_use_base_contract

**Default severity**: info. Enabled by default.

**WorkTracker-specific**: fixed `Base*Screen` convention under `screens/base/` and fixed exempt WorkTracker screen names. Disable outside WorkTracker.

## What it detects

Only when the project `lib/` contains a Dart file under `screens/base/`. In `GoRoute` and `MaterialPageRoute` `builder`/`pageBuilder` arguments that are not inside a `StatefulShellBranch`, public `*Screen` instantiations or `.new` tear-offs whose class, found by a text scan of `lib/`, extends a class not named `Base...Screen`. `SplashScreen`, `LockScreen`, `AuthScreen`, `MainShellScreen` and `AccountInactiveScreen` are exempt.

## Why

A shared base screen gives every top-level destination the same chrome, analytics and lifecycle hooks.

## Example

```dart
// BAD
GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())
// class ProfileScreen extends StatelessWidget
```

```dart
// GOOD
GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())
// class ProfileScreen extends BaseAuthenticatedScreen
```

## Disable if

In any project outside WorkTracker that does not adopt the same convention. You have a `screens/base/` folder but do not require top-level screens to extend it.

## Options

None. The exempt screen names are fixed.

## Limits

- Uses a cached regex scan of `lib/` source text, matching names only; screens not found in `lib/` are skipped.
- Only direct superclass names starting with `Base` and ending with `Screen` count; indirect bases are not resolved.
- Shell-branch routes defined in other files may still be checked.

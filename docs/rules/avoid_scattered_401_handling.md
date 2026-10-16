<!-- example-scope: isolated avoid_scattered_401_handling -->

> **Example contract: `avoid_scattered_401_handling` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# `avoid_scattered_401_handling`

Prevents 401 / unauthorized status-code checks outside of the designated
authentication boundary classes.

Scattered `statusCode == 401` checks across the codebase lead to inconsistent
token-refresh logic, duplicated retry flows, and hard-to-audit security
behaviour. All 401 handling must live in `AuthInterceptor` or `AuthService`.

## What it reports

Reports any `BinaryExpression` of the form `statusCode == 401` (or
`401 == statusCode`) that appears outside of a class named `AuthInterceptor`
or `AuthService`.

Message:

> 401 handling must be centralized in AuthInterceptor/AuthService. Avoid scattered authentication logic.

## Allowed classes

| Class | Reason |
|-------|--------|
| `AuthInterceptor` | HTTP interceptor — the right place for auth recovery |
| `AuthService` | Auth domain service — may inspect raw status codes |

## Examples

```dart
// ❌ BAD — 401 check inside a repository
class UserRepository {
  Future<User> getUser() async {
    final response = await client.get('/user');
    if (response.statusCode == 401) { // reported
      await refreshToken();
    }
  }
}

// ✅ GOOD — centralized in the interceptor
class AuthInterceptor {
  Future<Response> onResponse(Response response) async {
    if (response.statusCode == 401) { // allowed
      return await _refreshAndRetry(response);
    }
    return response;
  }
}
```

## Notes

- Test files (paths containing `/test/`) are automatically skipped.
- Generated files are automatically skipped.
- Detection is name-based (`statusCode` identifier or property access).

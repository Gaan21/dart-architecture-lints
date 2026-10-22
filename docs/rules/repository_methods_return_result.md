<!-- example-scope: isolated repository_methods_return_result -->

> **Example contract: `repository_methods_return_result` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# repository_methods_return_result

**Default severity**: info. Enabled by default.

## What it detects

In files whose URI path contains `/data/repositories/`, classes whose name ends with `Repository` or `RepositoryImpl`: public non-abstract methods (instance or static) returning a non-Result value, and getters returning `Future`/`FutureOr`/`Stream` of a non-Result value. Accepted: `Result`, or `Future`/`FutureOr`/`Stream` of `Result`, including typedef aliases. Excluded: synchronous getters, private members, setters, void-like returns, `==`, `toString`, `noSuchMethod`, `hashCode`, and unannotated members inferred as `dynamic`.

## Why

Expected failures stay typed outcomes for callers. Synchronous getters and private internal calculations may return values directly.

## Example

```dart
// BAD
class UserRepositoryImpl {
  Future<User> getById(String id) async => _map(await _source.fetch(id));
  Stream<List<User>> get users => _source.watch();
}
```

```dart
// GOOD
typedef AsyncResult<T> = Future<Result<T>>;
class UserRepositoryImpl {
  AsyncResult<User> getById(String id) => _guard(() => _source.fetch(id));
  bool get isCacheWarm => _cache.isNotEmpty;
  int _pageSize(int total) => total ~/ 20;
}
```

## Disable if

Your repositories throw or use another outcome protocol.

## Options

None.

## Limits

- Signature check only: it does not infer infallibility or purity from names; a public pure operation with expected rejection still needs `Result`.
- `Result` is matched by class name; abstract members and other folders (for example `/domain/repositories/`) are not checked.
- Shared classifier: `lib/result_return_types.dart`; see `no_result_throw` for bodies.

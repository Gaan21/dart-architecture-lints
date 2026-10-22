<!-- example-scope: isolated datasources_return_result -->

> **Example contract: `datasources_return_result` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# datasources_return_result

**Default severity**: info. Enabled by default.

## What it detects

In files whose URI path contains `/data/dataSources/` (exact casing), classes whose name ends with `DataSource` or `DataSourceImpl`: public methods (including abstract declarations) returning a non-Result value, and getters returning `Future`/`FutureOr`/`Stream` of a non-Result value. Accepted returns and exclusions are the same as `repository_methods_return_result`.

## Why

I/O and decoding failures reach repositories as typed outcomes instead of escaping exceptions.

## Example

```dart
// BAD
abstract interface class UserRemoteDataSource {
  Future<List<UserModel>> fetchUsers();
  Stream<UserModel> get changes;
}
```

```dart
// GOOD
abstract interface class UserRemoteDataSource {
  Future<Result<List<UserModel>>> fetchUsers();
  Stream<Result<UserModel>> watchUser(String id);
  Duration get timeout;
}
```

## Disable if

Your data sources throw by design and repositories own the conversion to `Result`.

## Options

None.

## Limits

- Folders spelled `datasources` or `data_sources` are not matched.
- Signature check only; it does not prove that every expected failure is converted. Extensions, mixins and top-level functions are not checked.

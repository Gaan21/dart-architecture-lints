<!-- example-scope: isolated no_direct_internet_calls -->

> **Example contract: `no_direct_internet_calls` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or acceptance by every rule. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_direct_internet_calls

**Default severity**: info. Enabled by default.

## What it detects

Outside network-service files: `Dio()`, `Client()`, `HttpClient()`, `IOClient()`, `BrowserClient()` and `Connectivity()` construction; `get`/`post`/`put`/`delete`/`patch`/`head`/`options` called on `http`, `Dio` or directly on a call/constructor result; and any call named `checkConnectivity`, `hasConnection` or `isConnected`. Calls whose target source contains `networkservice` are allowed. Network-service files are names containing `network_service`, `http_service`, `api_service`, `dio_service`, `connectivity_service` (with or without `_`), `di_container` or `dependency_injection`, or files under a `network`/`services` segment whose name contains `service` or `client`.

## Why

Central network access keeps connectivity, offline handling, authentication and error mapping consistent.

## Example

```dart
// BAD
final Response response = await Dio().get('/orders');
```

```dart
// GOOD
final Result<List<Order>> orders = await networkService.getOrders();
```

## Disable if

Your app has no central network abstraction, or calls the network from many deliberate places.

## Options

None. File indicators and method names are fixed.

## Limits

- Calls on a stored client variable (`dio.get(...)`) are not reported unless the target is itself a call or constructor; any class named `Client` is treated as an HTTP client.
- Connectivity method names are matched on any receiver except network-service targets.

<!-- example-scope: isolated require_explicit_types -->

> **Example contract: `require_explicit_types` only.** The inline contrast is a sketch. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md) for executed whole-profile acceptance.

# require_explicit_types

Default policy: `strict`. The architecture and style samples explicitly select
`policy: selective`. See [exact options and scopes](../configuration.md).

Strict mode checks fields, locals and supported loops for written annotations.
Selective mode checks public variable declarations and signatures, inferred
`dynamic` locals and names selected by `local_names`. Other local inference is
allowed. Resource rules resolve inferred types independently of this rule.

This original fixture is accepted by selective typing, strict class-containing
naming and getter-first method order together:

```dart
class RecordModel {
  int get count => 0;
  @override
  String toString() => 'record';
  int measure() {
    final recordModel = RecordModel();
    return recordModel.count;
  }
}
```

In strict mode, write `final RecordModel recordModel = RecordModel();` instead.
Changing typing policy does not change the naming or method-order contract.
The analyzer permits some inferred signatures; selective checking is an explicit
project policy rather than a claim that inference is invalid Dart.

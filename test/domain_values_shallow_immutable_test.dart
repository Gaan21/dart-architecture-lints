import 'package:dart_architecture_lints/domain_entities_must_use_freezed.dart';
import 'package:dart_architecture_lints/domain_values_shallow_immutable.dart';
import 'package:test/test.dart';

import 'rule_test_support.dart';

const _source = '''
const freezed = Freezed();
class Freezed { const Freezed(); }
class Record {
  Record(this.id, this.label);
  final String id;
  String label;
  late final int _hash = id.hashCode;
  late final String slug;
  static int created = 0;
  static const kind = 'record';
  final List<String> tags = [];
  set name(String value) {}
  int get hash => _hash;
}
@freezed
class Legacy { int count = 0; }
mixin Tracking { int visits = 0; }
abstract class Shape { abstract double area; }
''';

void main() {
  test('reports mutable fields, exposed late setters and setters', () async {
    final errors = await runRule(
      DomainValuesShallowImmutable(),
      _source,
      path: 'lib/domain/entities/record.dart',
    );
    final reported = {
      for (final error in errors)
        _source.substring(error.offset, error.offset + error.length),
    };
    expect(reported, {
      'label',
      'slug',
      'set name(String value) {}',
      'visits = 0',
      'area',
    });
  });

  test('value objects are in scope; other layers are not', () async {
    const value = 'class Email { Email(this.value); String value; }';
    expect(
      await runRule(
        DomainValuesShallowImmutable(),
        value,
        path: 'lib/domain/value_objects/email.dart',
      ),
      hasLength(1),
    );
    expect(
      await runRule(
        DomainValuesShallowImmutable(),
        _source,
        path: 'lib/data/models/record.dart',
      ),
      isEmpty,
    );
  });

  test('final plain classes pass without a generator annotation', () async {
    const plain = '''
class Money {
  const Money(this.cents, this.currency);
  final int cents;
  final String currency;
  Money add(Money other) => Money(cents + other.cents, currency);
}
''';
    const path = 'lib/domain/value_objects/money.dart';
    expect(
      await runRule(DomainValuesShallowImmutable(), plain, path: path),
      isEmpty,
    );
    // The Freezed convention is independent; projects without Freezed disable it.
    expect(
      await runRule(DomainEntitiesMustUseFreezed(), plain, path: path),
      hasLength(1),
    );
  });

  test('both immutability rules are enabled by default', () {
    final enabled = {
      for (final rule in pluginRegistry().enabled({})) rule.name,
    };
    expect(enabled, contains(DomainValuesShallowImmutable().name));
    expect(enabled, contains(DomainEntitiesMustUseFreezed().name));
  });
}

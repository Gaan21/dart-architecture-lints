import 'dart:io';
import 'package:test/test.dart';
import '../tool/example_docs.dart' as examples;
import '../tool/generate_rule_tables.dart' as generator;

void main() {
  test('all exact document scopes and generated coverage rows are checked', () {
    final registered = generator.registeredRules();
    final coverage = examples.exampleCoverage(registered.keys);
    for (final id in registered.keys) {
      expect(
        RegExp(RegExp.escape('| [`$id`]')).allMatches(coverage),
        hasLength(1),
      );
    }
    expect(File('docs/example_coverage.md').readAsStringSync(), coverage);
    expect(examples.checkedExamples(), hasLength(1));
  });
  test(
    'checked-example snippet claims require checked source and exact original bytes',
    () {
      final checked = examples.checkedExamples();
      final path = checked.first;
      final original = File(path).readAsStringSync();
      final claim = '<!-- checked-example: $path -->\n';
      examples.validateCheckedExampleClaims(
        '$claim```dart\n$original```',
        checked,
      );
      expect(
        () => examples.validateCheckedExampleClaims(
          '$claim```dart\n// different source\n```',
          checked,
        ),
        throwsFormatException,
      );
      expect(
        () => examples.validateCheckedExampleClaims(
          '${claim}Explanatory prose.\n\n```dart\n// different source\n```',
          checked,
        ),
        throwsFormatException,
      );
      expect(
        () => examples.validateCheckedExampleClaims(
          '<!-- checked-example: examples/unregistered.dart -->',
          checked,
        ),
        throwsFormatException,
      );
      expect(
        () => examples.validateCheckedExampleClaims(
          '$claim```dart\nunterminated',
          checked,
        ),
        throwsFormatException,
      );
      expect(
        () => examples.validateCheckedExampleClaims(
          '## All-rules example\n```dart\nvoid main() {}\n```',
          checked,
        ),
        throwsFormatException,
      );
    },
  );
}

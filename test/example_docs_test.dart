import 'dart:io';
import 'package:test/test.dart';
import '../tool/example_docs.dart' as examples;
import '../tool/generate_rule_tables.dart' as generator;

void main() {
  test(
    'all 51 exact document scopes and generated coverage rows are checked',
    () {
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
    },
  );
  test(
    'full-profile snippet claims require checked source and exact original bytes',
    () {
      final checked = examples.checkedExamples();
      final path = checked.first;
      final original = File(path).readAsStringSync();
      final claim = '<!-- full-profile-example: $path -->\n';
      examples.validateFullProfileClaims(
        '$claim```dart\n$original```',
        checked,
      );
      expect(
        () => examples.validateFullProfileClaims(
          '$claim```dart\n// different source\n```',
          checked,
        ),
        throwsFormatException,
      );
      expect(
        () => examples.validateFullProfileClaims(
          '${claim}Explanatory prose.\n\n```dart\n// different source\n```',
          checked,
        ),
        throwsFormatException,
      );
      expect(
        () => examples.validateFullProfileClaims(
          '<!-- full-profile-example: examples/unregistered.dart -->',
          checked,
        ),
        throwsFormatException,
      );
      expect(
        () => examples.validateFullProfileClaims(
          '$claim```dart\nunterminated',
          checked,
        ),
        throwsFormatException,
      );
      expect(
        () => examples.validateFullProfileClaims(
          '## Full-profile example\n```dart\nvoid main() {}\n```',
          checked,
        ),
        throwsFormatException,
      );
    },
  );
}

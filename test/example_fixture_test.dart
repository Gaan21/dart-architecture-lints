import 'dart:io';

import 'package:test/test.dart';

import '../tool/example_docs.dart';
import '../tool/generate_rule_tables.dart' as generator;
import 'rule_test_support.dart';

void main() {
  test(
    'checked example passes every registered rule with built-in defaults',
    () async {
      final rules = generator.registeredRules().values.toList();
      expect(rules, hasLength(52));
      for (final path in checkedExamples()) {
        final results = await runRules(
          rules,
          File(path).readAsStringSync(),
          path: path,
        );
        for (final entry in results.entries) {
          expect(entry.value, isEmpty, reason: '$path: ${entry.key}');
        }
      }
      final executed = await Process.run(Platform.resolvedExecutable, [
        'run',
        'examples/architecture/lib/presentation/viewModels/event_owner.dart',
      ]);
      expect(
        executed.exitCode,
        0,
        reason: '${executed.stdout}\n${executed.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

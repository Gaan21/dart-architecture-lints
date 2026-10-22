import 'dart:io';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';
import '../tool/example_docs.dart';
import '../tool/generate_rule_tables.dart' as generator;

void main() {
  test(
    'checked example passes every registered rule with default options',
    () async {
      final registered = generator.registeredRules();
      final rules = registered.values.whereType<DartLintRule>().toList();
      expect(rules, hasLength(registered.length));
      for (final path in checkedExamples()) {
        final file = File(path).absolute;
        final result = await resolveFile(path: file.path) as ResolvedUnitResult;
        expect(result.diagnostics, isEmpty, reason: path);
        for (final rule in rules) {
          expect(
            await rule.testAnalyzeAndRun(file),
            isEmpty,
            reason: '$path: ${rule.code.name}',
          );
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

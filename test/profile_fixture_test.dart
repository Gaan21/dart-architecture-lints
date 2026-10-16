import 'dart:io';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/dart_architecture_lints.dart';
import 'package:package_config/package_config.dart';
import 'package:test/test.dart';
import 'rule_test_support.dart';
import '../tool/example_docs.dart';

void main() {
  test(
    'documented selective example passes the complete architecture selection',
    () async {
      final configs = CustomLintConfigs.parse(
        PhysicalResourceProvider.INSTANCE.getFile(
          File('profiles/architecture.yaml').absolute.path,
        ),
        PackageConfig([]),
      );
      final rules = createPlugin()
          .getLintRules(configs)
          .whereType<DartLintRule>()
          .where((rule) => rule.isEnabled(configs))
          .toList();
      expect(rules, hasLength(48));
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
  test(
    'approved language exceptions coexist with strict style selections',
    () async {
      final configs = CustomLintConfigs.parse(
        PhysicalResourceProvider.INSTANCE.getFile(
          File('profiles/architecture.yaml').absolute.path,
        ),
        PackageConfig([]),
      );
      const languageIds = {
        'no_late_keyword',
        'no_bang_operator',
        'one_class_per_file',
      };
      const styleIds = {
        'method_order',
        'variable_name_should_contain_class_name',
        'require_explicit_types',
        'enforce_final_variables',
      };
      final rules = createPlugin()
          .getLintRules(configs)
          .whereType<DartLintRule>()
          .toList();
      const source = '''
class RecordModel {
  late final String _label = 'record';
  String get label => _label;
  String firstLabel(List<String?> labels) {
    if (labels.isEmpty || labels.first == null) throw StateError('missing label');
    return labels.first!;
  }
}
class RecordSnapshot { const RecordSnapshot(); }
''';
      final selected = rules
          .where(
            (rule) =>
                styleIds.contains(rule.code.name) && rule.isEnabled(configs),
          )
          .toList();
      expect(selected, hasLength(4));
      for (final result in (await runRules(selected, source)).entries) {
        expect(result.value, isEmpty, reason: result.key);
      }
      final legacy = CustomLintConfigs.parse(
        PhysicalResourceProvider.INSTANCE.getFile(
          File('profiles/legacy.yaml').absolute.path,
        ),
        PackageConfig([]),
      );
      final restrictions = rules
          .where(
            (rule) =>
                languageIds.contains(rule.code.name) && rule.isEnabled(legacy),
          )
          .toList();
      expect(restrictions, hasLength(3));
      for (final result in (await runRules(restrictions, source)).entries) {
        expect(result.value, isNotEmpty, reason: result.key);
      }
    },
  );
}

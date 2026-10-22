import 'dart:io';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/dart_architecture_lints.dart';
import 'package:dart_architecture_lints/require_explicit_types.dart';
import 'package:package_config/package_config.dart';
import 'package:test/test.dart';
import '../tool/generate_rule_tables.dart' as generator;

CustomLintConfigs parse(String path) => CustomLintConfigs.parse(
  PhysicalResourceProvider.INSTANCE.getFile(File(path).absolute.path),
  PackageConfig([]),
);

/// The single YAML fence under the README "Disable a rule" heading.
String readmeDisableExample() {
  final readme = File('README.md').readAsStringSync();
  final section = readme.split('\n## Disable a rule\n');
  expect(section, hasLength(2), reason: 'exactly one "Disable a rule" section');
  final match = RegExp(
    r'```yaml\n([\s\S]*?)```',
  ).firstMatch(section[1].split('\n## ').first);
  expect(match, isNotNull);
  return match!.group(1)!;
}

void main() {
  final rules = generator.registeredRules();
  test('public code, docs, tests and examples stay below 500 lines', () {
    final files = <File>[
      File('README.md'),
      File('CHANGELOG.md'),
      for (final path in ['lib', 'docs', 'tool', 'test', 'examples'])
        ...Directory(path).listSync(recursive: true).whereType<File>(),
    ];
    // Pre-existing regression suite, kept intact rather than split here.
    const preExisting = {
      'test/no_utc_time_format_without_empresa_helper_test.dart',
    };
    expect({
      for (final file in files)
        if (!preExisting.contains(file.path) &&
            file.readAsLinesSync().length >= 500)
          file.path: file.readAsLinesSync().length,
    }, isEmpty);
  });

  test('every registered rule is enabled by default', () {
    final empty = CustomLintConfigs.parse(null, PackageConfig([]));
    expect(rules, hasLength(52));
    expect([
      for (final rule in rules.values)
        if (!rule.enabledByDefault || !rule.isEnabled(empty)) rule.code.name,
    ], isEmpty);
  });

  test(
    'README disable example is consumed by the installed custom_lint parser',
    () async {
      final directory = await Directory.systemTemp.createTemp('disable_rule_');
      try {
        final file = File('${directory.path}/analysis_options.yaml');
        await file.writeAsString(readmeDisableExample());
        final configs = parse(file.path);
        final selected = createPlugin().getLintRules(configs);
        final disabled = {
          for (final rule in selected)
            if (!rule.isEnabled(configs)) rule.code.name,
        };
        expect(disabled, {'domain_entities_must_use_freezed'});
        expect(
          selected.whereType<RequireExplicitTypes>().single.policy,
          'selective',
        );
        expect(file.readAsStringSync(), contains('    method_order: warning'));
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('rule documents and metadata use the checked uniform format', () {
    generator.generatedFiles();
    final rule = rules['method_order']!;
    final valid = File('docs/rules/method_order.md').readAsStringSync();
    generator.validateRuleDoc('method_order', valid, rule);
    for (final broken in [
      valid.replaceFirst('\n## Disable if\n', '\n## Disable when\n'),
      valid.replaceFirst(
        'Default severity**: info',
        'Default severity**: error',
      ),
      valid.replaceFirst('\n# method_order\n', '\n# other_rule\n'),
    ]) {
      expect(
        () => generator.validateRuleDoc('method_order', broken, rule),
        throwsFormatException,
      );
    }
  });

  test(
    'generator check passes and unknown arguments fail',
    () async {
      final check = await Process.run(Platform.resolvedExecutable, [
        'run',
        'tool/generate_rule_tables.dart',
        '--check',
      ]);
      expect(check.exitCode, 0, reason: '${check.stdout}\n${check.stderr}');
      final unknown = await Process.run(Platform.resolvedExecutable, [
        'run',
        'tool/generate_rule_tables.dart',
        '--guidance-root',
      ]);
      expect(unknown.exitCode, isNonZero);
      expect(unknown.stderr, contains('Unknown argument'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

import 'dart:io';

import 'package:test/test.dart';

import '../tool/generate_rule_tables.dart' as generator;
import 'rule_test_support.dart';

/// The single YAML fence under the README "Disable a rule" heading.
String readmeDisableExample() {
  final readme = File('README.md').readAsStringSync();
  final section = readme.split('\n## Disable a rule\n');
  expect(section, hasLength(2), reason: 'exactly one "Disable a rule" section');
  final match = RegExp(r'```yaml\n([\s\S]*?)```')
      .firstMatch(section[1].split('\n## ').first);
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

  test('every registered rule is a warning rule, enabled by default', () {
    final registry = generator.recordRegistrations();
    expect(rules, hasLength(52));
    expect(registry.lintRules, isEmpty);
    expect(registry.warningRules, hasLength(rules.length));
    expect({
      for (final rule in pluginRegistry().enabled({})) rule.name,
    }, rules.keys.toSet());
  });

  test('every rule reports at info severity by default', () {
    expect(
      {for (final rule in rules.values) generator.defaultSeverity(rule)},
      {'info'},
    );
  });

  test(
    'README disable example is consumed by the analyzer plugin options parser',
    () async {
      final yaml = readmeDisableExample().replaceFirst(
        RegExp(r'    git:\n      url: [^\n]+\n      ref: [^\n]+\n'),
        '    path: ${Directory.current.path}\n',
      );
      expect(yaml, contains('    path: '));
      final selection = await pluginSelection(yaml);
      expect(rules.keys.toSet().difference(selection.enabled), {
        'domain_entities_must_use_freezed',
      });
      expect(selection.severities['method_order'], 'warning');
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

  test('generator check passes and unknown arguments fail', () async {
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
  }, timeout: const Timeout(Duration(minutes: 3)));
}

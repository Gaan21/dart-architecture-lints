import 'package:test/test.dart';

import '../tool/generate_rule_tables.dart' as generator;
import 'rule_cases.dart';
import 'rule_test_support.dart';

/// Every registered rule fires on at least one fixture and stays silent on
/// another. Counts match what the custom_lint 0.8.1 implementation reported.
void main() {
  final rules = generator.registeredRules();

  test('every registered rule has a positive and a negative case', () {
    final positive = {
      for (final c in ruleCases)
        if (c.reports > 0) c.rule,
    };
    final negative = {
      for (final c in ruleCases)
        if (c.reports == 0) c.rule,
    };
    expect(rules.keys.toSet().difference(positive), isEmpty);
    expect(rules.keys.toSet().difference(negative), isEmpty);
    expect(
      {for (final c in ruleCases) c.rule}.difference(rules.keys.toSet()),
      isEmpty,
    );
  });

  for (final c in ruleCases) {
    test('$c', () async {
      final rule = generator.registeredRules()[c.rule]!;
      final diagnostics = await runRule(
        rule,
        c.text(),
        path: c.path,
        files: c.files,
        packageConfig: true,
        mustResolve: false,
      );
      expect(diagnostics, hasLength(c.reports));
    });
  }

  // Added with the analyzer plugin: suppressions must name the plugin, so the
  // prefixed form is checked like the bare one (which custom_lint used).
  for (final (reason, reports) in [
    ('', 1),
    ('// ignore-reason: legacy\n  ', 0),
  ]) {
    test('prefixed avoid_unawaited ignore reports $reports', () async {
      final diagnostics = await runRule(
        generator.registeredRules()['avoid_unawaited_ignore_without_reason']!,
        '''
import 'dart:async';
Future<void> cleanup() async {}
void run() {
  $reason// ignore: dart_architecture_lints/avoid_unawaited
  unawaited(cleanup());
}
''',
      );
      expect(diagnostics, hasLength(reports));
    });
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/generate_rule_tables.dart' as generator;
import 'rule_test_support.dart';

void main() {
  final rules = generator.registeredRules();
  final metadata = generator.readMetadata(rules);
  final specific = {
    for (final entry in metadata)
      if (entry['worktracker_reason']!.isNotEmpty) entry['id']!,
  };

  test(
    'README outside-WorkTracker block disables exactly the marked rules',
    () async {
      final readme = File('README.md').readAsStringSync();
      final block = generator.worktrackerDisableYaml(metadata);
      expect(readme, contains(block));
      final yaml = RegExp(r'```yaml\n([\s\S]*?)```')
          .firstMatch(block)!
          .group(1)!;
      final selection = await pluginSelection(_withPluginSource(yaml));
      final disabled = rules.keys.toSet().difference(selection.enabled);
      expect(specific, isNotEmpty);
      expect(disabled, specific);
    },
  );

  test('WorkTracker marking in rule documents is enforced both ways', () {
    final marked = metadata.firstWhere(
      (entry) => entry['id'] == 'avoid_scattered_401_handling',
    );
    final reason = marked['worktracker_reason']!;
    final markedRule = rules['avoid_scattered_401_handling']!;
    final markedDoc = File('docs/rules/avoid_scattered_401_handling.md')
        .readAsStringSync();
    generator.validateRuleDoc(
      'avoid_scattered_401_handling',
      markedDoc,
      markedRule,
      worktrackerReason: reason,
    );
    for (final broken in [
      markedDoc.replaceFirst(generator.worktrackerLine(reason), ''),
      markedDoc.replaceFirst('outside WorkTracker that', 'elsewhere that'),
    ]) {
      expect(
        () => generator.validateRuleDoc(
          'avoid_scattered_401_handling',
          broken,
          markedRule,
          worktrackerReason: reason,
        ),
        throwsFormatException,
      );
    }
    // A marked document must also be classified as specific in metadata.
    expect(
      () => generator.validateRuleDoc(
        'avoid_scattered_401_handling',
        markedDoc,
        markedRule,
      ),
      throwsFormatException,
    );
    final generic = File('docs/rules/method_order.md').readAsStringSync();
    expect(
      () => generator.validateRuleDoc(
        'method_order',
        generic,
        rules['method_order']!,
        worktrackerReason: 'fixed names',
      ),
      throwsFormatException,
    );
  });

  test('metadata requires a consistent WorkTracker classification', () {
    final raw =
        jsonDecode(File('tool/rule_metadata.json').readAsStringSync()) as List;
    List<Object?> mutate(void Function(Map<String, dynamic> entry) change) {
      final copy = jsonDecode(jsonEncode(raw)) as List;
      change(
        copy.cast<Map<String, dynamic>>().firstWhere(
          (entry) => entry['id'] == 'avoid_scattered_401_handling',
        ),
      );
      return copy;
    }

    generator.readMetadata(rules, raw);
    for (final broken in [
      mutate((entry) => entry.remove('worktracker_specific')),
      mutate((entry) => entry.remove('worktracker_reason')),
      mutate((entry) => entry['worktracker_specific'] = false),
      mutate((entry) => entry['worktracker_specific'] = 'yes'),
    ]) {
      expect(
        () => generator.readMetadata(rules, broken),
        throwsFormatException,
      );
    }
  });
}

/// Adds a local plugin source under the consumer's `dart_architecture_lints:`
/// key, so the analyzer's parser accepts a block that only sets diagnostics.
String _withPluginSource(String yaml) => yaml.replaceFirst(
  '  dart_architecture_lints:\n',
  '  dart_architecture_lints:\n    path: ${Directory.current.path}\n',
);

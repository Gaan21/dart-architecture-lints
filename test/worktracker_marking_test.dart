import 'dart:convert';
import 'dart:io';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/dart_architecture_lints.dart';
import 'package:package_config/package_config.dart';
import 'package:test/test.dart';
import '../tool/generate_rule_tables.dart' as generator;

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
      final yaml = RegExp(
        r'```yaml\n([\s\S]*?)```',
      ).firstMatch(block)!.group(1)!;
      final directory = await Directory.systemTemp.createTemp(
        'worktracker_off_',
      );
      try {
        final file = File('${directory.path}/analysis_options.yaml');
        await file.writeAsString(yaml);
        final configs = CustomLintConfigs.parse(
          PhysicalResourceProvider.INSTANCE.getFile(file.path),
          PackageConfig([]),
        );
        final disabled = {
          for (final rule in createPlugin().getLintRules(configs))
            if (!rule.isEnabled(configs)) rule.code.name,
        };
        expect(specific, isNotEmpty);
        expect(disabled, specific);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('WorkTracker marking in rule documents is enforced both ways', () {
    final marked = metadata.firstWhere(
      (entry) => entry['id'] == 'avoid_scattered_401_handling',
    );
    final reason = marked['worktracker_reason']!;
    final markedRule = rules['avoid_scattered_401_handling']!;
    final markedDoc = File(
      'docs/rules/avoid_scattered_401_handling.md',
    ).readAsStringSync();
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

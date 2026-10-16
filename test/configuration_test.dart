import 'dart:io';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/dart_architecture_lints.dart';
import 'package:dart_architecture_lints/require_explicit_types.dart';
import 'package:dart_architecture_lints/logger_context_matches_scope.dart';
import 'package:package_config/package_config.dart';
import 'package:test/test.dart';
import '../tool/generate_rule_tables.dart' as generator;

CustomLintConfigs parse(String path) => CustomLintConfigs.parse(
  PhysicalResourceProvider.INSTANCE.getFile(File(path).absolute.path),
  PackageConfig([]),
);

void main() {
  final rules = generator.registeredRules();
  test(
    'public code, guidance, alignment fixtures and samples stay below 500 lines',
    () {
      final files = <File>[
        File('README.md'),
        File('analysis_options.yaml.template'),
        File('test/alignment_test.dart'),
        File('test/configuration_test.dart'),
        File('test/profile_fixture_test.dart'),
        File('test/rule_test_support.dart'),
        File('test/guidance_contract_test.dart'),
        File('test/contract_export_test.dart'),
        File('test/review_regressions_test.dart'),
        File('test/example_docs_test.dart'),
        File('test/doc_sketch_regression_test.dart'),
        for (final path in ['lib', 'docs', 'tool', 'profiles', 'examples'])
          ...Directory(path).listSync(recursive: true).whereType<File>(),
      ];
      expect({
        for (final file in files)
          if (file.readAsLinesSync().length >= 500)
            file.path: file.readAsLinesSync().length,
      }, isEmpty);
    },
  );
  test('all 51 legacy registrations remain enabled by default', () {
    expect(rules, hasLength(51));
    expect(
      rules.values.every(
        (rule) =>
            rule.isEnabled(CustomLintConfigs.parse(null, PackageConfig([]))),
      ),
      isTrue,
    );
  });
  test('every profile explicitly selects every registration', () {
    for (final path in [
      'analysis_options.yaml.template',
      'profiles/architecture.yaml',
      'profiles/legacy.yaml',
      'profiles/style.yaml',
    ]) {
      final source = File(path).readAsStringSync();
      generator.validateConfiguration(source, rules.keys.toSet());
      expect(parse(path).rules.keys.toSet(), rules.keys.toSet());
    }
  });
  test(
    'architecture options are consumed by the installed custom_lint parser',
    () {
      final configs = parse('analysis_options.yaml.template');
      final selected = createPlugin().getLintRules(configs);
      expect(selected.where((rule) => rule.isEnabled(configs)), hasLength(48));
      expect(
        selected
            .where((rule) => !rule.isEnabled(configs))
            .map((rule) => rule.code.name)
            .toSet(),
        {'no_late_keyword', 'no_bang_operator', 'one_class_per_file'},
      );
      expect(configs.rules['no_static_map_controllers']!.enabled, isTrue);
      expect(configs.rules['mixin_no_state_ownership']!.enabled, isTrue);
      expect(
        selected.whereType<RequireExplicitTypes>().single.policy,
        'selective',
      );
      final logger = selected.whereType<LoggerContextMatchesScopeLint>().single;
      expect(logger.includeGlobs, ['**/lib/**']);
      expect(logger.loggerNames, ['Logger', 'logger']);
      expect(configs.rules['method_order']!.enabled, isTrue);
      expect(
        configs.rules['variable_name_should_contain_class_name']!.enabled,
        isTrue,
      );
    },
  );
  test(
    'legacy keeps strict typing and style is an explicit reduced selection',
    () {
      final legacy = parse('profiles/legacy.yaml');
      expect(
        rules.values.where((rule) => rule.isEnabled(legacy)),
        hasLength(51),
      );
      expect(
        createPlugin()
            .getLintRules(legacy)
            .whereType<RequireExplicitTypes>()
            .single
            .policy,
        'strict',
      );
      final style = parse('profiles/style.yaml');
      expect(
        rules.values
            .where((rule) => rule.isEnabled(style))
            .map((rule) => rule.code.name)
            .toSet(),
        {
          'method_order',
          'variable_name_should_contain_class_name',
          'require_explicit_types',
          'enforce_final_variables',
        },
      );
      expect(style.rules['one_class_per_file']!.enabled, isFalse);
      expect(RequireExplicitTypes.fromConfigs(style).policy, 'selective');
      expect(style.rules['method_order']!.enabled, isTrue);
      expect(
        style.rules['variable_name_should_contain_class_name']!.enabled,
        isTrue,
      );
      expect(style.rules['multiprovider_order']!.enabled, isFalse);
    },
  );
  test(
    'architecture alias and template are generated from identical selections',
    () {
      expect(
        File('profiles/architecture.yaml').readAsStringSync(),
        File('analysis_options.yaml.template').readAsStringSync(),
      );
    },
  );
  test(
    'stale, duplicate, incomplete and unsupported syntax fail deterministically',
    () {
      for (final source in [
        'custom_lint:\n  rules:\n    - check_context_mounted: true\n',
        'custom_lint:\n  rules:\n    - method_order\n    - method_order\n',
        'custom_lint:\n  rules: {method_order: info}\n',
        'custom_lint:\n  rules:\n    - require_explicit_types:\n        policy: selective\n',
        'custom_lint:\n  rules:\n    - method_order: true\n',
      ]) {
        expect(
          () => generator.validateConfiguration(source, rules.keys.toSet()),
          throwsFormatException,
        );
      }
    },
  );
}

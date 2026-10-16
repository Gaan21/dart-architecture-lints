import 'dart:io';
import 'package:dart_architecture_lints/method_order_rule.dart';
import 'package:dart_architecture_lints/no_static_map_controllers.dart';
import 'package:dart_architecture_lints/require_explicit_types.dart';
import 'package:dart_architecture_lints/variable_name_should_match_class_name.dart';
import 'package:test/test.dart';
import 'rule_test_support.dart';

void main() {
  test(
    'actual scoped-controller doc sketch retains strict names, getter-first order and types',
    () async {
      final markdown = File(
        'docs/rules/no_static_map_controllers.md',
      ).readAsStringSync();
      final source = RegExp(
        r'class SearchUiState extends ChangeNotifier \{.*?\n\}',
        dotAll: true,
      ).firstMatch(markdown)!.group(0)!;
      // Original minimal stand-ins resolve this isolated snippet without importing
      // framework tutorials or pretending this is a Flutter rendering test.
      final results = await runRules(
        [
          const NoStaticMapControllersLint(),
          const MethodOrderRule(),
          const VariableNameShouldMatchClassName(),
          const RequireExplicitTypes(),
        ],
        '''
import 'dart:async';
class ChangeNotifier { void dispose() {} }
class TextEditingController { void dispose() {} }
$source
''',
      );
      for (final entry in results.entries) {
        expect(entry.value, isEmpty, reason: entry.key);
      }
      expect(
        markdown,
        contains('final TextEditingController textEditingController'),
      );
    },
  );
}

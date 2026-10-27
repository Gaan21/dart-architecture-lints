// ignore_for_file: deprecated_member_use

import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:test/test.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

import 'rule_test_support.dart';

import 'package:dart_architecture_lints/no_domain_entities_in_presentation_ui.dart';

void main() {
  group('no_domain_entities_in_presentation_ui', () {
    test('reports entities barrel import in presentation/screens', () async {
      final errors = await _runRule(
        rule: NoDomainEntitiesInPresentationUiLint(),
        relativeFilePath: 'lib/presentation/screens/dashboard_screen.dart',
        source: '''
import 'package:lint_test_project/domain/entities/entities.dart';

class DashboardScreen {}
''',
      );

      expect(
        _errorCodes(errors),
        contains('no_domain_entities_in_presentation_ui'),
      );
    });

    test(
      'reports domain entities file import in presentation/widgets',
      () async {
        final errors = await _runRule(
          rule: NoDomainEntitiesInPresentationUiLint(),
          relativeFilePath: 'lib/presentation/widgets/worker_tile.dart',
          source: '''
import 'package:lint_test_project/domain/entities/worker_entity.dart';

class WorkerTile {}
''',
        );

        expect(
          _errorCodes(errors),
          contains('no_domain_entities_in_presentation_ui'),
        );
      },
    );

    test(
      'does not report when file is explicit _ui_mapper exception',
      () async {
        final errors = await _runRule(
          rule: NoDomainEntitiesInPresentationUiLint(),
          relativeFilePath:
              'lib/presentation/screens/incidencias/incidencias_ui_mapper.dart',
          source: '''
import 'package:lint_test_project/domain/entities/incidencia_entity.dart';

class IncidenciasUiMapper {}
''',
        );

        expect(
          _errorCodes(errors),
          isNot(contains('no_domain_entities_in_presentation_ui')),
        );
      },
    );

    test('does not report ui model import in presentation/screens', () async {
      final errors = await _runRule(
        rule: NoDomainEntitiesInPresentationUiLint(),
        relativeFilePath: 'lib/presentation/screens/dashboard_screen.dart',
        source: '''
import 'package:lint_test_project/presentation/models/worker_ui_model.dart';

class DashboardScreen {}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_domain_entities_in_presentation_ui')),
      );
    });

    test('defaults to the analyzed package, not another package', () async {
      final errors = await _runRule(
        rule: NoDomainEntitiesInPresentationUiLint(),
        relativeFilePath: 'lib/presentation/screens/dashboard_screen.dart',
        source: '''
import 'package:work_tracker/domain/entities/entities.dart';

class DashboardScreen {}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_domain_entities_in_presentation_ui')),
      );
    });

    test('an explicit package name overrides the analyzed package', () async {
      const source = '''
import 'package:work_tracker/domain/entities/entities.dart';
import 'package:lint_test_project/domain/entities/entities.dart';

class DashboardScreen {}
''';
      final errors = await _runRule(
        rule: NoDomainEntitiesInPresentationUiLint(
          config: const NoDomainEntitiesInPresentationUiConfig(
            projectPackageName: 'work_tracker',
          ),
        ),
        relativeFilePath: 'lib/presentation/screens/dashboard_screen.dart',
        source: source,
      );

      expect(errors, hasLength(1));
      expect(
        source
            .substring(errors.single.offset)
            .startsWith("'package:work_tracker/"),
        isTrue,
      );
    });

    test('package name falls back to the analyzed pubspec name', () {
      expect(
        NoDomainEntitiesInPresentationUiLint.analyzedPackageName(
          Uri.parse('package:my_app/presentation/screens/a.dart'),
          'other',
        ),
        'my_app',
      );
      expect(
        NoDomainEntitiesInPresentationUiLint.analyzedPackageName(
          Uri.file('/tmp/project/lib/presentation/screens/a.dart'),
          'my_app',
        ),
        'my_app',
      );
    });

    test('does not report outside presentation/screens and widgets', () async {
      final errors = await _runRule(
        rule: NoDomainEntitiesInPresentationUiLint(),
        relativeFilePath: 'lib/domain/usecases/get_worker_usecase.dart',
        source: '''
import 'package:lint_test_project/domain/entities/entities.dart';

class GetWorkerUseCase {}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_domain_entities_in_presentation_ui')),
      );
    });
  });
}

Future<List<Diagnostic>> _runRule({
  required GeneratedSkippingDartLintRule rule,
  required String relativeFilePath,
  required String source,
}) => runRule(
  rule,
  source,
  path: relativeFilePath,
  packageName: 'lint_test_project',
  sdk: '>=3.5.0 <4.0.0',
  packageConfig: true,
  mustResolve: false,
);

Set<String> _errorCodes(List<Diagnostic> errors) {
  return errors.map((error) => error.diagnosticCode.lowerCaseName).toSet();
}

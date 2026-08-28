// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';
import 'package:dart_architecture_lints/no_domain_entities_in_presentation_ui.dart';

void main() {
  group('no_domain_entities_in_presentation_ui', () {
    test('reports entities barrel import in presentation/screens', () async {
      final errors = await _runRule(
        rule: const NoDomainEntitiesInPresentationUiLint(),
        relativeFilePath: 'lib/presentation/screens/dashboard_screen.dart',
        source: '''
import 'package:work_tracker/domain/entities/entities.dart';

class DashboardScreen {}
''',
      );

      expect(
        _errorCodes(errors),
        contains('no_domain_entities_in_presentation_ui'),
      );
    });

    test('reports domain entities file import in presentation/widgets',
        () async {
      final errors = await _runRule(
        rule: const NoDomainEntitiesInPresentationUiLint(),
        relativeFilePath: 'lib/presentation/widgets/worker_tile.dart',
        source: '''
import 'package:work_tracker/domain/entities/worker_entity.dart';

class WorkerTile {}
''',
      );

      expect(
        _errorCodes(errors),
        contains('no_domain_entities_in_presentation_ui'),
      );
    });

    test('does not report when file is explicit _ui_mapper exception',
        () async {
      final errors = await _runRule(
        rule: const NoDomainEntitiesInPresentationUiLint(),
        relativeFilePath:
            'lib/presentation/screens/incidencias/incidencias_ui_mapper.dart',
        source: '''
import 'package:work_tracker/domain/entities/incidencia_entity.dart';

class IncidenciasUiMapper {}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_domain_entities_in_presentation_ui')),
      );
    });

    test('does not report ui model import in presentation/screens', () async {
      final errors = await _runRule(
        rule: const NoDomainEntitiesInPresentationUiLint(),
        relativeFilePath: 'lib/presentation/screens/dashboard_screen.dart',
        source: '''
import 'package:work_tracker/presentation/models/worker_ui_model.dart';

class DashboardScreen {}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_domain_entities_in_presentation_ui')),
      );
    });

    test('does not report outside presentation/screens and widgets', () async {
      final errors = await _runRule(
        rule: const NoDomainEntitiesInPresentationUiLint(),
        relativeFilePath: 'lib/domain/usecases/get_worker_usecase.dart',
        source: '''
import 'package:work_tracker/domain/entities/entities.dart';

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

Future<List<AnalysisError>> _runRule({
  required DartLintRule rule,
  required String relativeFilePath,
  required String source,
}) async {
  final tempDir =
      await Directory.systemTemp.createTemp('presentation_domain_lint_test_');
  try {
    final pubspec = File('${tempDir.path}/pubspec.yaml');
    await pubspec.writeAsString('''
name: lint_test_project
environment:
  sdk: ">=3.5.0 <4.0.0"
''');

    final file = File('${tempDir.path}/$relativeFilePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(source);

    return await rule.testAnalyzeAndRun(file);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Set<String> _errorCodes(List<AnalysisError> errors) {
  return errors.map((error) => error.errorCode.name).toSet();
}

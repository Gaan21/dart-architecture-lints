// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

/// Original resolved fixtures fail on compiler errors as well as lint counts.
Future<List<AnalysisError>> runRule(
  DartLintRule rule,
  String source, {
  String path = 'lib/example.dart',
}) async => (await runRules([rule], source, path: path))[rule.code.name]!;

Future<Map<String, List<AnalysisError>>> runRules(
  List<DartLintRule> rules,
  String source, {
  String path = 'lib/example.dart',
}) async {
  final directory = await Directory.systemTemp.createTemp('alignment_fixture_');
  try {
    await File('${directory.path}/pubspec.yaml').writeAsString('''
name: alignment_fixture
environment:
  sdk: '>=3.8.0 <4.0.0'
''');
    final file = File('${directory.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString(source);
    final resolved = await resolveFile2(path: file.path) as ResolvedUnitResult;
    expect(
      resolved.errors.where(
        (error) => error.errorCode.errorSeverity == ErrorSeverity.ERROR,
      ),
      isEmpty,
      reason: 'Fixture must resolve: $source',
    );
    return {
      for (final rule in rules)
        rule.code.name: await rule.testAnalyzeAndRun(file),
    };
  } finally {
    await directory.delete(recursive: true);
  }
}

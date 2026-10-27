// The test harness drives the analyzer's own registries and option parser, as
// analyzer_testing does; their implementations are not public API.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:analysis_server_plugin/src/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/analysis_options/analysis_options.dart';
import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer_testing/utilities/utilities.dart';
import 'package:dart_architecture_lints/dart_architecture_lints.dart';
import 'package:test/test.dart';

/// Runs [rule] on [source] written at [path] in a fresh package.
Future<List<Diagnostic>> runRule(
  AbstractAnalysisRule rule,
  String source, {
  String path = 'lib/example.dart',
  String packageName = 'alignment_fixture',
  String sdk = '>=3.8.0 <4.0.0',
  bool packageConfig = false,
  bool mustResolve = true,
  Map<String, String> files = const {},
}) async => (await runRules(
  [rule],
  source,
  path: path,
  packageName: packageName,
  sdk: sdk,
  packageConfig: packageConfig,
  mustResolve: mustResolve,
  files: files,
))[rule.name]!;

/// Runs [rules] through the analyzer's resolved lint pipeline (real SDK).
///
/// Fixtures that must resolve fail on compiler errors as well as lint counts.
/// [packageConfig] writes a resolved package config, so `package:` imports of
/// the fixture's own package resolve. [files] adds other files of the package.
Future<Map<String, List<Diagnostic>>> runRules(
  List<AbstractAnalysisRule> rules,
  String source, {
  String path = 'lib/example.dart',
  String packageName = 'alignment_fixture',
  String sdk = '>=3.8.0 <4.0.0',
  bool packageConfig = false,
  bool mustResolve = true,
  Map<String, String> files = const {},
}) async {
  final directory = await Directory.systemTemp.createTemp('alignment_fixture_');
  AnalysisContextCollection? collection;
  try {
    for (final rule in rules) {
      Registry.ruleRegistry.registerLintRule(rule);
    }
    await File('${directory.path}/pubspec.yaml').writeAsString('''
name: $packageName
environment:
  sdk: '$sdk'
''');
    await File('${directory.path}/analysis_options.yaml').writeAsString(
      analysisOptionsContent(rules: [for (final rule in rules) rule.name]),
    );
    if (packageConfig) {
      final config = File('${directory.path}/.dart_tool/package_config.json');
      await config.parent.create(recursive: true);
      await config.writeAsString('''
{"configVersion": 2, "packages": [
  {"name": "$packageName", "rootUri": "../", "packageUri": "lib/"}
]}
''');
    }
    for (final entry in {...files, path: source}.entries) {
      final other = File('${directory.path}/${entry.key}');
      await other.parent.create(recursive: true);
      await other.writeAsString(entry.value);
    }
    final file = File('${directory.path}/$path');
    collection = AnalysisContextCollection(includedPaths: [directory.path]);
    final result =
        await collection
                .contextFor(file.path)
                .currentSession
                .getResolvedUnit(file.path)
            as ResolvedUnitResult;
    if (mustResolve) {
      expect(
        result.diagnostics.where(
          (diagnostic) =>
              diagnostic.diagnosticCode.severity == DiagnosticSeverity.ERROR,
        ),
        isEmpty,
        reason: 'Fixture must resolve: $source',
      );
    }
    return {
      for (final rule in rules)
        rule.name: [
          for (final diagnostic in result.diagnostics)
            if (rule.diagnosticCodes.contains(diagnostic.diagnosticCode))
              diagnostic,
        ],
    };
  } finally {
    await collection?.dispose();
    await directory.delete(recursive: true);
  }
}

/// The diagnostic names in [diagnostics].
Set<String> codeNames(List<Diagnostic> diagnostics) => {
  for (final diagnostic in diagnostics) diagnostic.diagnosticCode.lowerCaseName,
};

/// A registry filled by the plugin exactly as the analysis server fills it.
PluginRegistryImpl pluginRegistry() {
  final registry = PluginRegistryImpl('dart_architecture_lints');
  DartArchitectureLintsPlugin().register(registry);
  return registry;
}

/// The rules the analysis server enables for [analysisOptions], parsed by the
/// analyzer's own options parser, plus each configured severity.
Future<({Set<String> enabled, Map<String, String> severities})> pluginSelection(
  String analysisOptions,
) async {
  final directory = await Directory.systemTemp.createTemp('plugin_options_');
  AnalysisContextCollection? collection;
  try {
    await File('${directory.path}/pubspec.yaml')
        .writeAsString('name: consumer\nenvironment:\n  sdk: ^3.8.0\n');
    await File('${directory.path}/analysis_options.yaml')
        .writeAsString(analysisOptions);
    final file = File('${directory.path}/lib/a.dart');
    await file.parent.create(recursive: true);
    await file.writeAsString('');
    collection = AnalysisContextCollection(includedPaths: [directory.path]);
    final options =
        collection
                .contextFor(file.path)
                .getAnalysisOptionsForFile(
                  PhysicalResourceProvider.INSTANCE.getFile(file.path),
                )
            as AnalysisOptionsImpl;
    final configuration = options.pluginConfigurations.singleWhere(
      (configuration) => configuration.name == 'dart_architecture_lints',
    );
    final configs = {
      for (final entry in configuration.diagnosticConfigs.entries)
        entry.key.toLowerCase(): entry.value,
    };
    return (
      enabled: {
        if (configuration.isEnabled)
          for (final rule in pluginRegistry().enabled(configs)) rule.name,
      },
      severities: {
        for (final entry in configs.entries)
          entry.key: entry.value.severity.name,
      },
    );
  } finally {
    await collection?.dispose();
    await directory.delete(recursive: true);
  }
}

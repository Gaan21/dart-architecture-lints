import 'dart:convert';
import 'dart:io';

import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:dart_architecture_lints/dart_architecture_lints.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

import 'example_docs.dart';

/// Records what the plugin registers, as the analysis server receives it.
class RecordingRegistry implements PluginRegistry {
  /// Rules registered as warning rules: enabled unless a project disables them.
  final warningRules = <AbstractAnalysisRule>[];

  /// Rules registered as lint rules: disabled unless a project enables them.
  final lintRules = <AbstractAnalysisRule>[];

  @override
  void registerWarningRule(AbstractAnalysisRule rule) => warningRules.add(rule);

  @override
  void registerLintRule(AbstractAnalysisRule rule) => lintRules.add(rule);

  @override
  void registerAssist(generator) {}

  @override
  void registerFixForRule(code, generator) {}

  @override
  Iterable<AbstractAnalysisRule> enabled(ruleConfigs) =>
      throw UnsupportedError('Recording only');
}

/// The plugin's live registrations, keyed by rule ID.
RecordingRegistry recordRegistrations() {
  final registry = RecordingRegistry();
  DartArchitectureLintsPlugin().register(registry);
  return registry;
}

/// Uses live registrations, never a second list of rule IDs or severities.
Map<String, GeneratedSkippingDartLintRule> registeredRules() {
  final registry = recordRegistrations();
  final registered = [...registry.warningRules, ...registry.lintRules];
  final rules = {
    for (final rule in registered.cast<GeneratedSkippingDartLintRule>())
      rule.name: rule,
  };
  if (registered.length != rules.length) {
    throw StateError('Duplicate registration');
  }
  return rules;
}

/// The default severity a rule reports, before `diagnostics:` overrides.
String defaultSeverity(GeneratedSkippingDartLintRule rule) =>
    rule.code.severity.name.toLowerCase();

/// Metadata fields every rule must provide, each a single non-empty line.
const metadataFields = ['id', 'section', 'detects', 'disable_if'];

/// Classification fields: `worktracker_specific` (bool) and, only when true, a
/// one-line `worktracker_reason` naming what is fixed to WorkTracker.
const classificationFields = ['worktracker_specific', 'worktracker_reason'];

/// Reads `tool/rule_metadata.json` and requires exact registration membership.
///
/// Each returned entry has the string fields plus `worktracker_reason`, which
/// is empty for rules that are not WorkTracker-specific.
List<Map<String, String>> readMetadata(
  Map<String, GeneratedSkippingDartLintRule> rules, [
  Object? decoded,
]) {
  final raw =
      decoded ?? jsonDecode(File('tool/rule_metadata.json').readAsStringSync());
  final metadata = <Map<String, String>>[];
  for (final entry in (raw as List).cast<Map<String, dynamic>>()) {
    final known = {...metadataFields, ...classificationFields};
    if (entry.keys.toSet().difference(known).isNotEmpty) {
      throw FormatException('Unknown metadata keys: ${entry.keys}');
    }
    final specific = entry['worktracker_specific'];
    if (specific is! bool) {
      throw FormatException(
        '${entry['id']}: "worktracker_specific" must be a bool',
      );
    }
    if (specific != entry.containsKey('worktracker_reason')) {
      throw FormatException(
        '${entry['id']}: "worktracker_reason" is required exactly when '
        '"worktracker_specific" is true',
      );
    }
    for (final field in [
      ...metadataFields,
      if (specific) 'worktracker_reason',
    ]) {
      final value = entry[field];
      if (value is! String || value.trim().isEmpty || value.contains('\n')) {
        throw FormatException('${entry['id']}: "$field" must be one line');
      }
      if (value.contains('|')) {
        throw FormatException('${entry['id']}: "$field" must not contain |');
      }
    }
    metadata.add({
      for (final field in metadataFields) field: entry[field] as String,
      'worktracker_reason': specific
          ? entry['worktracker_reason'] as String
          : '',
    });
  }
  final ids = metadata.map((entry) => entry['id']!).toSet();
  if (ids.length != metadata.length ||
      ids.difference(rules.keys.toSet()).isNotEmpty ||
      rules.keys.toSet().difference(ids).isNotEmpty) {
    throw StateError(
      'Metadata must match live registrations exactly: '
      'stale=${ids.difference(rules.keys.toSet())}, '
      'missing=${rules.keys.toSet().difference(ids)}',
    );
  }
  return metadata;
}

/// Copy-paste YAML that disables every WorkTracker-specific rule at once.
String worktrackerDisableYaml(List<Map<String, String>> metadata) {
  final ids = [
    for (final entry in metadata)
      if (entry['worktracker_reason']!.isNotEmpty) entry['id']!,
  ]..sort();
  return [
    '```yaml',
    'plugins:',
    '  dart_architecture_lints:',
    '    diagnostics:',
    for (final id in ids) '      $id: false',
    '```',
  ].join('\n');
}

/// The rule-document line that marks a WorkTracker-specific rule.
String worktrackerLine(String reason) =>
    '**WorkTracker-specific**: $reason. Disable outside WorkTracker.';

/// Required headings of every rule document, in order.
const ruleDocHeadings = [
  '## What it detects',
  '## Why',
  '## Example',
  '## Disable if',
  '## Options',
  '## Limits',
];

/// Checks the uniform rule-document format against the live rule and, when
/// [worktrackerReason] is non-empty, the WorkTracker-specific marking.
void validateRuleDoc(
  String id,
  String text,
  GeneratedSkippingDartLintRule rule, {
  String worktrackerReason = '',
}) {
  final path = 'docs/rules/$id.md';
  if (!text.contains('\n# $id\n')) {
    throw FormatException('$path: missing "# $id" title');
  }
  final severity = defaultSeverity(rule);
  if (!text.contains('**Default severity**: $severity. Enabled by default.')) {
    throw FormatException('$path: severity line must say $severity');
  }
  var position = 0;
  for (final heading in ruleDocHeadings) {
    final index = text.indexOf('\n$heading\n', position);
    if (index < 0) {
      throw FormatException('$path: missing or misordered $heading');
    }
    position = index + heading.length;
  }
  final marked = text.contains('**WorkTracker-specific**');
  if (worktrackerReason.isEmpty) {
    if (marked) {
      throw FormatException('$path: not WorkTracker-specific in metadata');
    }
  } else {
    if (!text.contains('\n${worktrackerLine(worktrackerReason)}\n')) {
      throw FormatException(
        '$path: needs the line "${worktrackerLine(worktrackerReason)}"',
      );
    }
    final disableIf = text.substring(
      text.indexOf('\n## Disable if\n'),
      text.indexOf('\n## Options\n'),
    );
    if (!disableIf.contains('outside WorkTracker')) {
      throw FormatException(
        '$path: "Disable if" must mention outside WorkTracker',
      );
    }
  }
  if (const LineSplitter().convert(text).length > 120) {
    throw FormatException('$path: keep rule documents at most 120 lines');
  }
}

const usage = '''Usage: dart run tool/generate_rule_tables.dart [--check]

Generate README rule tables and the documentation coverage matrix from live
registrations and tool/rule_metadata.json, and check every rule document.
  --check    Report drift without writing files (exit code 1 on drift).
  -h, --help Show this help without generating files.
''';

void main(List<String> args) {
  final unknown = args.where(
    (arg) => !const {'--check', '--help', '-h'}.contains(arg),
  );
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown argument: ${unknown.first}\n$usage');
    exitCode = 1;
    return;
  }
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(usage);
    return;
  }
  try {
    generate(check: args.contains('--check'));
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

/// Returns generated file contents keyed by path, after validating sources.
Map<String, String> generatedFiles() {
  final rules = registeredRules();
  final metadata = readMetadata(rules);
  final disabled = [
    for (final rule in recordRegistrations().lintRules) rule.name,
  ];
  if (disabled.isNotEmpty) {
    throw FormatException('Every rule must be enabled by default: $disabled');
  }
  final generated = <String, String>{...scopedRuleDocs(rules.keys)};
  for (final entry in metadata) {
    final id = entry['id']!;
    validateRuleDoc(
      id,
      generated['docs/rules/$id.md']!,
      rules[id]!,
      worktrackerReason: entry['worktracker_reason']!,
    );
  }
  var readme = File('README.md').readAsStringSync();
  readme = replaceSection(
    readme,
    'AUTOGENERATED:RULE_TOTAL_COUNTS',
    '**Total**: **${rules.length} registered rules**, all enabled by default. '
        'Severity is the actual LintCode default, before `diagnostics` overrides.',
  );
  final sections = <String, List<Map<String, String>>>{};
  for (final entry in metadata) {
    sections.putIfAbsent(entry['section']!, () => []).add(entry);
  }
  for (final section in sections.entries) {
    final buffer = StringBuffer(
      '| Rule | WorkTracker | Detects | Disable if | Default severity |\n'
      '|------|-------------|---------|------------|------------------|\n',
    );
    for (final entry in section.value) {
      final id = entry['id']!;
      buffer.writeln(
        '| [`$id`](docs/rules/$id.md) | '
        '${entry['worktracker_reason']!.isEmpty ? '' : '⚠️ specific'} | '
        '${entry['detects']} | '
        '${entry['disable_if']} | '
        '${defaultSeverity(rules[id]!)} |',
      );
    }
    readme = replaceSection(
      readme,
      'AUTOGENERATED:${section.key}',
      buffer.toString().trimRight(),
    );
  }
  readme = replaceSection(
    readme,
    'AUTOGENERATED:WORKTRACKER_DISABLE',
    worktrackerDisableYaml(metadata),
  );
  generated['README.md'] = readme;
  generated['docs/example_coverage.md'] = exampleCoverage(rules.keys);
  return generated;
}

void generate({required bool check}) {
  final generated = generatedFiles();
  for (final entry in generated.entries) {
    final file = File(entry.key);
    if (check) {
      if (!file.existsSync() || file.readAsStringSync() != entry.value) {
        stderr.writeln('Generated file drift: ${entry.key}');
        exitCode = 1;
      }
    } else {
      file.writeAsStringSync(entry.value);
    }
  }
  stdout.writeln(
    '${check ? 'Checked' : 'Generated'} README tables and rule documents.',
  );
}

String replaceSection(String content, String marker, String replacement) {
  final startTag = '<!-- $marker -->';
  final endTag = '<!-- END $marker -->';
  if (startTag.allMatches(content).length != 1 ||
      endTag.allMatches(content).length != 1) {
    throw FormatException(
      'Expected exactly one opening and closing marker: $marker',
    );
  }
  final start = content.indexOf(startTag);
  final end = content.indexOf(endTag, start);
  if (end < start) throw FormatException('Reversed markers: $marker');
  return '${content.substring(0, start + startTag.length)}\n$replacement\n${content.substring(end)}';
}

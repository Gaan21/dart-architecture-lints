import 'dart:convert';
import 'dart:io';

import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/dart_architecture_lints.dart';
import 'package:package_config/package_config.dart';
import 'package:yaml/yaml.dart';
import 'contract_export.dart';
import 'example_docs.dart';

/// Uses live registrations, never a second list of rule IDs or severities.
Map<String, LintRule> registeredRules() {
  final registered = createPlugin().getLintRules(
    CustomLintConfigs.parse(null, PackageConfig([])),
  );
  final rules = {for (final rule in registered) rule.code.name: rule};
  if (registered.length != rules.length) {
    throw StateError('Duplicate registration');
  }
  return rules;
}

/// Validates the list syntax actually consumed by custom_lint 0.8.1.
void validateConfiguration(
  String source,
  Set<String> registered, {
  bool complete = true,
}) {
  final yaml = loadYaml(source) as Map;
  final custom = yaml['custom_lint'] as Map;
  final entries = custom['rules'];
  if (entries is! List) {
    throw FormatException('custom_lint.rules must be a list');
  }
  final seen = <String>{};
  for (final entry in entries) {
    final id = entry is String ? entry : (entry as Map).keys.first as String;
    if (!registered.contains(id)) {
      throw FormatException('Unregistered rule: $id');
    }
    if (!seen.add(id)) throw FormatException('Duplicate rule: $id');
    if (entry is Map) {
      if (entry.values.first is! bool && entry.values.first != null) {
        throw FormatException('$id: use a boolean and sibling option keys');
      }
      if (entry.containsKey('severity')) {
        throw FormatException('Put severity overrides under analyzer.errors');
      }
    }
  }
  if (complete && seen.length != registered.length) {
    throw FormatException('Missing selections: ${registered.difference(seen)}');
  }
  final errors = (yaml['analyzer'] as Map?)?['errors'];
  if (errors is Map) {
    for (final id in errors.keys) {
      if (!registered.contains(id)) {
        throw FormatException('Unregistered severity: $id');
      }
    }
  }
}

const _styleRules = {
  'method_order',
  'variable_name_should_contain_class_name',
  'enforce_final_variables',
  'require_explicit_types',
};

const _approvedLanguageExceptions = {
  'no_late_keyword',
  'no_bang_operator',
  'one_class_per_file',
};

/// The same selections drive generated YAML and the read-only guidance check.
Map<String, bool> profileSelections(Iterable<String> registered, String kind) {
  if (!const {'legacy', 'architecture', 'style'}.contains(kind)) {
    throw ArgumentError.value(kind, 'kind', 'Unknown profile');
  }
  return {
    for (final id in registered.toList()..sort())
      id: switch (kind) {
        'legacy' => true,
        'architecture' => !_approvedLanguageExceptions.contains(id),
        _ => _styleRules.contains(id),
      },
  };
}

/// Reads Rule/Selection table rows only; prose and fenced examples are ignored.
void validateGuidance(String markdown, Map<String, bool> expected) {
  final seen = <String>{};
  var inTable = false;
  String? fence;
  for (final raw in const LineSplitter().convert(markdown)) {
    final line = raw.trim();
    final marker = RegExp(r'^(`{3,}|~{3,})').firstMatch(line)?.group(1);
    if (marker != null) {
      if (fence == null) {
        fence = marker;
      } else if (marker[0] == fence[0] && marker.length >= fence.length) {
        fence = null;
      }
      inTable = false;
      continue;
    }
    if (fence != null) continue;
    if (!line.startsWith('|') || !line.endsWith('|')) {
      inTable = false;
      continue;
    }
    final cells = line
        .substring(1, line.length - 1)
        .split('|')
        .map((cell) => cell.trim())
        .toList();
    if (cells.length >= 2 && cells[0] == 'Rule' && cells[1] == 'Selection') {
      inTable = true;
      continue;
    }
    if (!inTable) continue;
    if (cells.length >= 2 &&
        cells.take(2).every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell))) {
      continue;
    }
    final id = RegExp(r'^`([^`]+)`$').firstMatch(cells[0])?.group(1);
    if (id == null || cells.length < 2) {
      throw FormatException(
        'Expected a backticked rule ID and Selection cell: $line',
      );
    }
    if (!expected.containsKey(id)) {
      throw FormatException('Unknown guidance rule: $id');
    }
    if (!seen.add(id)) throw FormatException('Duplicate guidance rule: $id');
    final state = cells[1];
    if (state != 'enabled' && state != 'disabled') {
      throw FormatException('Invalid guidance selection for $id: $state');
    }
    final wanted = expected[id]! ? 'enabled' : 'disabled';
    if (state != wanted) {
      throw FormatException(
        'Guidance selection for $id: expected $wanted, got $state',
      );
    }
  }
  final missing = expected.keys.toSet().difference(seen).toList()..sort();
  if (missing.isNotEmpty) {
    throw FormatException('Missing guidance rules: ${missing.join(', ')}');
  }
}

const usage =
    '''Usage: dart run tool/generate_rule_tables.dart [--check] [--guidance-root PATH]
       [--export-contract PATH] [--verify-contract PATH]

Generate registered rule tables and explicit profile selections.
  --check                Check generated files without writing them.
  --guidance-root PATH   Read PATH/profiles/architecture.md and verify its
                         Rule/Selection table against architecture selections.
                         Never writes to PATH; accepts enabled/disabled cells.
  --export-contract PATH Write canonical architecture identity JSON to PATH.
  --verify-contract PATH Compare PATH byte-for-byte with this checkout's contract.
                         Contract operations check source without regenerating it.
  -h, --help             Show this help without generating files.
''';

class GeneratorOptions {
  GeneratorOptions({
    this.check = false,
    this.guidanceRoot,
    this.help = false,
    this.exportPath,
    this.verifyPath,
  });
  final bool check, help;
  final String? guidanceRoot, exportPath, verifyPath;

  factory GeneratorOptions.parse(List<String> args) {
    var check = false;
    var help = false;
    final paths = <String, String>{};
    for (var index = 0; index < args.length; index++) {
      final argument = args[index];
      if (argument == '--check') {
        check = true;
      } else if (argument == '--help' || argument == '-h') {
        help = true;
      } else if (const {
        '--guidance-root',
        '--export-contract',
        '--verify-contract',
      }.contains(argument.split('=').first)) {
        final flag = argument.split('=').first;
        if (paths.containsKey(flag)) throw FormatException('Duplicate $flag');
        String path;
        if (argument == flag) {
          if (++index >= args.length || args[index].startsWith('--')) {
            throw FormatException('$flag requires PATH');
          }
          path = args[index];
        } else {
          path = argument.substring(flag.length + 1);
        }
        if (path.trim().isEmpty) {
          throw FormatException('$flag requires PATH');
        }
        paths[flag] = path;
      } else {
        throw FormatException('Unknown argument: $argument');
      }
    }
    return GeneratorOptions(
      check: check,
      guidanceRoot: paths['--guidance-root'],
      exportPath: paths['--export-contract'],
      verifyPath: paths['--verify-contract'],
      help: help,
    );
  }
}

String profile(Map<String, LintRule> rules, String kind) {
  final output = StringBuffer(
    '''# Generated by tool/generate_rule_tables.dart; edit selections in your project.
# $kind selection. See docs/configuration.md before adopting a profile.
analyzer:
  plugins:
    - custom_lint
custom_lint:
  enable_all_lint_rules: false
  rules:
''',
  );
  for (final entry in profileSelections(rules.keys, kind).entries) {
    final id = entry.key;
    final enabled = entry.value;
    output.writeln('    - $id: $enabled');
    if (enabled && kind != 'legacy' && id == 'require_explicit_types') {
      output.writeln('      policy: selective');
    }
    if (enabled &&
        kind == 'architecture' &&
        id == 'logger_context_matches_scope') {
      output.writeln('      include_globs: ["**/lib/**"]');
      output.writeln('      logger_names: ["Logger", "logger"]');
    }
  }
  return output.toString();
}

void main(List<String> args) {
  try {
    final options = GeneratorOptions.parse(args);
    if (options.help) {
      stdout.write(usage);
      return;
    }
    generate(options);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

void generate(GeneratorOptions options) {
  final check =
      options.check || options.exportPath != null || options.verifyPath != null;
  final rules = registeredRules();
  if (options.guidanceRoot != null) {
    final file = File.fromUri(
      Directory(
        options.guidanceRoot!,
      ).absolute.uri.resolve('profiles/architecture.md'),
    );
    final selections = profileSelections(rules.keys, 'architecture');
    validateGuidance(file.readAsStringSync(), selections);
    final enabled = selections.values.where((value) => value).length;
    stdout.writeln(
      'Guidance table matches all ${rules.length} registrations: '
      '$enabled enabled, ${rules.length - enabled} disabled.',
    );
  }
  final metadata =
      (jsonDecode(File('tool/rule_metadata.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  final ids = metadata.map((entry) => entry['id'] as String).toSet();
  if (ids.length != metadata.length ||
      ids.difference(rules.keys.toSet()).isNotEmpty ||
      rules.keys.toSet().difference(ids).isNotEmpty) {
    throw StateError(
      'Metadata must match live registrations exactly: '
      'stale=${ids.difference(rules.keys.toSet())}, '
      'missing=${rules.keys.toSet().difference(ids)}',
    );
  }
  final generated = <String, String>{
    'analysis_options.yaml.template': profile(rules, 'architecture'),
    'profiles/architecture.yaml': profile(rules, 'architecture'),
    'profiles/legacy.yaml': profile(rules, 'legacy'),
    'profiles/style.yaml': profile(rules, 'style'),
    ...scopedRuleDocs(rules.keys),
  };
  for (final entry in generated.entries) {
    if (entry.key.endsWith('.yaml') || entry.key.endsWith('.template')) {
      validateConfiguration(entry.value, rules.keys.toSet());
    }
  }
  final sections = <String, List<Map<String, dynamic>>>{};
  for (final entry in metadata) {
    sections.putIfAbsent(entry['section'] as String, () => []).add(entry);
  }
  var readme = File('README.md').readAsStringSync();
  readme = replaceSection(
    readme,
    'AUTOGENERATED:RULE_TOTAL_COUNTS',
    '**Total**: **${rules.length} registered rules**. All are enabled by default; '
        'severity below is the actual LintCode default, before analyzer overrides.',
  );
  for (final section in sections.entries) {
    final buffer = StringBuffer(
      '| Rule | Description | Default severity |\n'
      '|------|-------------|------------------|\n',
    );
    for (final entry in section.value) {
      final rule = rules[entry['id']]!;
      buffer.writeln(
        '| `${entry['id']}` | ${entry['description']} | '
        '${rule.code.errorSeverity.name.toLowerCase()} |',
      );
    }
    readme = replaceSection(
      readme,
      'AUTOGENERATED:${section.key}',
      buffer.toString().trimRight(),
    );
  }
  generated['README.md'] = readme;
  generated['docs/example_coverage.md'] = exampleCoverage(rules.keys);
  for (final entry in generated.entries) {
    final file = File(entry.key);
    if (check) {
      if (!file.existsSync() || file.readAsStringSync() != entry.value) {
        stderr.writeln('Generated file drift: ${entry.key}');
        exitCode = 1;
      }
      // Validate checked-in files too, so stale entries fail explicitly.
      if (entry.key.endsWith('.yaml') || entry.key.endsWith('.template')) {
        if (file.existsSync()) {
          validateConfiguration(file.readAsStringSync(), rules.keys.toSet());
        }
      }
    } else {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
    }
  }
  stdout.writeln(
    '${check ? 'Checked' : 'Generated'} ${rules.length} rule selections and tables.',
  );
  if (exitCode != 0) return;
  if (options.exportPath != null || options.verifyPath != null) {
    final contract = exportContract(
      Directory.current,
      expectedArchitecture: profile(rules, 'architecture'),
    );
    if (options.verifyPath != null) {
      verifyContract(File(options.verifyPath!), contract);
      stdout.writeln('Contract matches this checkout.');
    }
    if (options.exportPath != null) {
      writeContract(File(options.exportPath!), contract, Directory.current);
      stdout.writeln('Exported canonical architecture contract.');
      stdout.writeln(
        'Source digest: ${(jsonDecode(contract) as Map)['source_digest']}',
      );
    }
  }
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

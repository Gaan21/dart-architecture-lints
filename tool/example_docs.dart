import 'dart:convert';
import 'dart:io';

List<String> checkedExamples() =>
    (jsonDecode(File('tool/checked_examples.json').readAsStringSync()) as List)
        .cast<String>();

/// Keep each explicit isolated contract visible before the tutorial, not buried.
Map<String, String> scopedRuleDocs(Iterable<String> registered) => {
  for (final id in registered)
    'docs/rules/$id.md': _frontScope(
      File('docs/rules/$id.md').readAsStringSync(),
      id,
    ),
};

String _frontScope(String text, String id) {
  final pattern = RegExp(
    '${RegExp.escape('<!-- example-scope: isolated $id -->')}\\s*\\n>[^\\n]+',
  );
  final match = pattern.firstMatch(text);
  if (match == null) return text;
  return '${match.group(0)!.trim()}\n\n${text.replaceRange(match.start, match.end, '').trim()}\n';
}

/// Claims must refer to original source that the full-selection test consumes.
void validateFullProfileClaims(String markdown, List<String> checked) {
  final declaration = RegExp(r'<!-- full-profile-example: ([^>]+) -->');
  for (final match in declaration.allMatches(markdown)) {
    final path = match.group(1)!.trim();
    if (!checked.contains(path) || !File(path).existsSync()) {
      throw FormatException('Untested full-profile example: $path');
    }
  }
  // Explicitly full-profile sections cannot contain unregistered Dart fences.
  String section = '';
  String? claim;
  String? source;
  List<String>? snippet;
  var fenced = false;
  for (final line in const LineSplitter().convert(markdown)) {
    if (line.startsWith('```')) {
      if (!fenced &&
          line.trim() == '```dart' &&
          RegExp(
            r'(?:full|whole)-profile',
            caseSensitive: false,
          ).hasMatch(section) &&
          claim == null) {
        throw FormatException(
          'Full-profile Dart fence needs a checked-source declaration',
        );
      }
      if (!fenced && line.trim() == '```dart' && claim != null) {
        source = claim;
        snippet = [];
      } else if (fenced && snippet != null) {
        if (snippet.join('\n').trim() !=
            File(source!).readAsStringSync().trim()) {
          throw FormatException(
            'Full-profile snippet differs from checked source: $source',
          );
        }
        snippet = null;
      }
      fenced = !fenced;
      claim = null;
    } else if (fenced) {
      snippet?.add(line);
    } else if (!fenced) {
      if (line.startsWith('#')) {
        section = line;
        claim = null;
      }
      final match = declaration.firstMatch(line);
      if (match != null) claim = match.group(1)!.trim();
    }
  }
  if (snippet != null) {
    throw FormatException('Unterminated full-profile snippet: $source');
  }
}

String exampleCoverage(Iterable<String> registered) {
  final checked = checkedExamples();
  if (checked.toSet().length != checked.length || checked.isEmpty) {
    throw FormatException(
      'Checked example registry must be nonempty and unique',
    );
  }
  for (final path in checked) {
    if (!path.startsWith('examples/architecture/') ||
        path.contains('..') ||
        !File(path).existsSync()) {
      throw FormatException('Invalid checked example path: $path');
    }
  }
  final output = StringBuffer('''# Documentation example coverage

Generated from live diagnostic IDs and the actual rule documents.

## Executed full-profile sources

`test/profile_fixture_test.dart` resolves every source below, runs all 48 selected
rules against it, and executes the runnable entry. These are the only canonical
full-profile sources; this is not behavior coverage of all 51 diagnostics.

''');
  for (final path in checked) {
    output.writeln('- [$path](../$path)');
  }
  output.writeln();
  output.writeln(
    '''
## Rule-document audit

Every row names the exact isolated diagnostic contract. Dart fences include
positive/negative contrasts and partial setup snippets. None is represented as a
compiled full-profile fixture unless it exactly references checked source.
Counts audit the actual files, not a second manually maintained rule catalogue.
Explicit annotations in isolated sketches may illustrate legacy strict typing;
they do not override selective locals in the architecture recommendation. Partial
framework/service sketches can omit declarations and retain names/order relevant
only to their isolated contrast. Do not paste them as full-profile implementations.
The static-map ownership sketch additionally has a source-extracted style/order
regression in `test/doc_sketch_regression_test.dart` using original local stand-ins.

| Diagnostic / document | Dart fences | Local contract | Full-profile path |
|-----------------------|-------------|----------------|-------------------|''',
  );
  for (final id in registered.toList()..sort()) {
    final path = 'docs/rules/$id.md';
    final text = File(path).readAsStringSync();
    final scope = '<!-- example-scope: isolated $id -->';
    if (scope.allMatches(text).length != 1) {
      throw FormatException('Missing/duplicate exact example scope: $path');
    }
    validateFullProfileClaims(text, checked);
    final fences = RegExp(
      r'^```dart\s*$',
      multiLine: true,
    ).allMatches(text).length;
    output.writeln(
      '| [`$id`](rules/$id.md) | $fences | ${fences == 0 ? 'Prose only' : 'Isolated `$id`; not compiled acceptance'} | [Checked sources](../examples/architecture/README.md) |',
    );
  }
  // Check claims in every public Markdown document, including the example guide.
  for (final directory in ['docs', 'examples']) {
    for (final file in Directory(
      directory,
    ).listSync(recursive: true).whereType<File>()) {
      if (file.path.endsWith('.md')) {
        validateFullProfileClaims(file.readAsStringSync(), checked);
      }
    }
  }
  validateFullProfileClaims(File('README.md').readAsStringSync(), checked);
  return output.toString();
}

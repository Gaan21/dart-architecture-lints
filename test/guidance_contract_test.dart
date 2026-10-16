import 'dart:io';
import 'package:test/test.dart';
import '../tool/generate_rule_tables.dart' as generator;

String table(Map<String, bool> selections) =>
    '''
# Architecture guidance

| Rule | Selection | Contract |
|------|-----------|----------|
${selections.entries.map((entry) => '| `${entry.key}` | ${entry.value ? 'enabled' : 'disabled'} | Original guidance |').join('\n')}
''';

void main() {
  final expected = generator.profileSelections(
    generator.registeredRules().keys,
    'architecture',
  );
  final valid = table(expected);
  const enabledRow = '| `method_order` | enabled | Original guidance |';
  const disabledRow = '| `no_bang_operator` | disabled | Original guidance |';

  test(
    'complete table matches 51 registrations and 48 architecture selections',
    () {
      expect(expected, hasLength(51));
      expect(expected.values.where((enabled) => enabled), hasLength(48));
      generator.validateGuidance(valid, expected);
    },
  );
  final mutations = <String, String>{
    'duplicate': '$valid$enabledRow\n',
    'missing': valid.replaceFirst('$enabledRow\n', ''),
    'unknown': '$valid| `unknown_diagnostic` | enabled | Unknown |\n',
    'enabled rule disabled': valid.replaceFirst(
      enabledRow,
      enabledRow.replaceFirst('enabled', 'disabled'),
    ),
    'disabled rule enabled': valid.replaceFirst(
      disabledRow,
      disabledRow.replaceFirst('disabled', 'enabled'),
    ),
    'invalid state': valid.replaceFirst(
      enabledRow,
      enabledRow.replaceFirst('enabled', 'true'),
    ),
    'non-exact state': valid.replaceFirst(
      enabledRow,
      enabledRow.replaceFirst('enabled', '`enabled`'),
    ),
    'unquoted rule': valid.replaceFirst('`method_order`', 'method_order'),
    'no table header': valid.replaceFirst(
      '| Rule | Selection | Contract |',
      '| Diagnostic | State | Contract |',
    ),
  };
  for (final mutation in mutations.entries) {
    test('rejects ${mutation.key}', () {
      expect(
        () => generator.validateGuidance(mutation.value, expected),
        throwsFormatException,
      );
    });
  }
  test('prose and fenced examples do not supply rows or create duplicates', () {
    generator.validateGuidance('''
`method_order` is discussed in prose, not selected here.
```markdown
$valid
```
~~~markdown
$valid
~~~
$valid
''', expected);
    expect(
      () => generator.validateGuidance('```markdown\n$valid\n```', expected),
      throwsFormatException,
    );
    expect(
      () => generator.validateGuidance('$valid\n${table(expected)}', expected),
      throwsFormatException,
    );
  });
  test('CLI option parsing and help contract', () {
    final options = generator.GeneratorOptions.parse([
      '--check',
      '--guidance-root',
      'guidance root',
    ]);
    expect(options.check, isTrue);
    expect(options.guidanceRoot, 'guidance root');
    expect(
      generator.GeneratorOptions.parse(['--guidance-root=root']).guidanceRoot,
      'root',
    );
    expect(generator.GeneratorOptions.parse(['--help']).help, isTrue);
    for (final args in [
      ['--guidance-root'],
      ['--guidance-root='],
      ['--guidance-root', '--check'],
      ['--unknown'],
      ['--guidance-root=a', '--guidance-root=b'],
    ]) {
      expect(
        () => generator.GeneratorOptions.parse(args),
        throwsFormatException,
      );
    }
  });
  test(
    'CLI cross-check reads a temporary guidance root and never edits it',
    () async {
      final root = await Directory.systemTemp.createTemp('guidance contract ');
      try {
        final file = File('${root.path}/profiles/architecture.md');
        await file.parent.create();
        await file.writeAsString(valid);
        final modified = await file.lastModified();
        final result = await Process.run(Platform.resolvedExecutable, [
          'run',
          'tool/generate_rule_tables.dart',
          '--check',
          '--guidance-root',
          root.path,
        ]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(
          result.stdout,
          contains('51 registrations: 48 enabled, 3 disabled'),
        );
        expect(await file.readAsString(), valid);
        expect(await file.lastModified(), modified);
        final broken = valid.replaceFirst(
          disabledRow,
          disabledRow.replaceFirst('disabled', 'enabled'),
        );
        await file.writeAsString(broken);
        final failure = await Process.run(Platform.resolvedExecutable, [
          'run',
          'tool/generate_rule_tables.dart',
          '--check',
          '--guidance-root=${root.path}',
        ]);
        expect(failure.exitCode, isNonZero);
        expect(failure.stderr, contains('expected disabled, got enabled'));
        expect(await file.readAsString(), broken);
        expect(
          root
              .listSync(recursive: true)
              .whereType<File>()
              .map((file) => file.path),
          [file.path],
        );
        final help = await Process.run(Platform.resolvedExecutable, [
          File('tool/generate_rule_tables.dart').absolute.path,
          '--help',
        ], workingDirectory: root.path);
        expect(help.exitCode, 0, reason: '${help.stderr}');
        expect(help.stdout, contains('--guidance-root PATH'));
        expect(help.stdout, contains('Never writes to PATH'));
      } finally {
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

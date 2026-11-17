import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_architecture_lints/avoid_unawaited.dart';
import 'package:test/test.dart';

import 'rule_test_support.dart';

void main() {
  final fingerprint = sha256
      .convert(
        utf8.encode(jsonEncode(['unawaited', '(', 'work', '(', ')', ')'])),
      )
      .toString();
  final permission = {
    'path': 'lib/example.dart',
    'scope': 'function:run',
    'fingerprint': fingerprint,
    'whyDetached': 'A synchronous callback starts independent cleanup.',
    'failureOwner': 'The cleanup owner reports failures.',
    'lateCompletion': 'The cleanup does not touch current state.',
  };
  Map<String, String> files(List<Object> entries) => {
    'pubspec.yaml': '''
name: alignment_fixture
environment:
  sdk: ^3.13.0
dart_architecture_lints_unawaited_permissions: permits.json
''',
    'permits.json': jsonEncode({'version': 1, 'permissions': entries}),
  };
  const declarations = '''
import 'dart:async';
Future<void> work() async {}
Future<void> other() async {}
''';

  test(
    'allows one exact call without comments, even after reformatting',
    () async {
      expect(
        await runRule(AvoidUnawaitedLint(), '''
${declarations}void run() {
  unawaited(
    work(), // Formatter may change the trailing comma.
  );
}
''', files: files([permission])),
        isEmpty,
      );
    },
  );

  test('a new call fails despite a legacy marker', () async {
    final diagnostics = await runRule(AvoidUnawaitedLint(), '''
${declarations}void run() {
  unawaited(work());
  unawaited(other()); // unawaited-ok: callback-sync - not a permission
}
''', files: files([permission]));
    expect(diagnostics.single.message, contains('no permission'));
  });

  test('identical adjacent copies both fail as ambiguous', () async {
    final diagnostics = await runRule(AvoidUnawaitedLint(), '''
${declarations}void run() { unawaited(work()); unawaited(work()); }
''', files: files([permission]));
    expect(diagnostics, hasLength(2));
    expect(
      diagnostics.map((d) => d.message),
      everyElement(contains('ambiguous')),
    );
  });

  test(
    'an identical call in another named scope does not inherit permission',
    () async {
      final diagnostics = await runRule(AvoidUnawaitedLint(), '''
${declarations}void run() { unawaited(work()); }
void otherScope() { unawaited(work()); }
''', files: files([permission]));
      expect(diagnostics.single.message, contains('no permission'));
    },
  );

  test('reports stale entries even in a file with no calls', () async {
    final diagnostics = await runRule(AvoidUnawaitedLint(), '''
${declarations}void run() {}
''', files: files([permission]));
    expect(diagnostics.single.message, contains('stale permission'));
  });

  test(
    'duplicate manifest entries are invalid, not a fallback to legacy',
    () async {
      final diagnostics = await runRule(
        AvoidUnawaitedLint(),
        '${declarations}void run() { unawaited(work()); }',
        files: files([permission, permission]),
      );
      expect(diagnostics.single.message, contains('duplicate selector'));
    },
  );

  test('missing manifest does not fall back to legacy', () async {
    final diagnostics = await runRule(
      AvoidUnawaitedLint(),
      '''${declarations}void run() {
  // unawaited-ok: callback-sync - legacy justification
  unawaited(work());
}
''',
      files: files([])..remove('permits.json'),
    );
    expect(diagnostics.single.message, contains('Cannot read permission'));
  });

  test('legacy mode still honors a valid marker', () async {
    final diagnostics = await runRule(AvoidUnawaitedLint(), '''
${declarations}void run() {
  // unawaited-ok: callback-sync - legacy justification
  unawaited(work());
  unawaited(other());
}
''');
    expect(diagnostics, hasLength(1));
    expect(diagnostics.single.message, contains('sin justificación'));
  });
}

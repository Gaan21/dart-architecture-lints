import 'package:dart_architecture_lints/logger_context_matches_scope.dart';
import 'package:test/test.dart';

import 'rule_test_support.dart';

const _source = '''
class AppLoggerService {
  static void error(String message, {String? context}) {}
}
class SyncService {
  void push() { AppLoggerService.error('failed', context: 'SyncService.pull'); }
  void pull() { AppLoggerService.error('failed', context: 'SyncService.pull'); }
}
''';

void main() {
  test('default scope checks any package lib file', () async {
    // The fixture package is not named work_tracker; it is checked by default.
    final errors = await runRule(
      LoggerContextMatchesScopeLint(),
      _source,
      path: 'lib/data/sync_service.dart',
    );
    expect(errors, hasLength(1));
  });

  test('explicit include and exclude globs still override', () async {
    for (final rule in [
      LoggerContextMatchesScopeLint(includeGlobs: ['**/lib/ui/**']),
      LoggerContextMatchesScopeLint(excludeGlobs: ['**/data/**']),
      LoggerContextMatchesScopeLint(includeGlobs: []),
    ]) {
      expect(
        await runRule(rule, _source, path: 'lib/data/sync_service.dart'),
        isEmpty,
      );
    }
    expect(
      await runRule(
        LoggerContextMatchesScopeLint(includeGlobs: ['**/data/**']),
        _source,
        path: 'lib/data/sync_service.dart',
      ),
      hasLength(1),
    );
  });

  test('files outside lib are not checked by default', () async {
    expect(
      await runRule(
        LoggerContextMatchesScopeLint(),
        _source,
        path: 'tool/sync_service.dart',
      ),
      isEmpty,
    );
  });
}

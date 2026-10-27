// ignore_for_file: deprecated_member_use

import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:dart_architecture_lints/no_civil_utc_mix_without_helper.dart';
import 'package:dart_architecture_lints/no_device_local_in_presentation.dart';
import 'package:test/test.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

import 'rule_test_support.dart';

void main() {
  group('no_device_local_in_presentation', () {
    test('reports toLocal() in presentation file', () async {
      final errors = await _runRule(
        rule: NoDeviceLocalInPresentationLint(),
        relativeFilePath: 'lib/presentation/home_screen.dart',
        source: '''
DateTime formatDate(DateTime serverValue) {
  return serverValue.toLocal();
}
''',
      );

      expect(_errorCodes(errors), contains('no_device_local_in_presentation'));
    });

    test('does not report outside included globs', () async {
      final errors = await _runRule(
        rule: NoDeviceLocalInPresentationLint(),
        relativeFilePath: 'lib/domain/entities/event.dart',
        source: '''
DateTime normalize(DateTime value) {
  return value.toLocal();
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_device_local_in_presentation')),
      );
    });

    test('respects allowed receiver and wrappers', () async {
      final errors = await _runRule(
        rule: NoDeviceLocalInPresentationLint(
          config: NoDeviceLocalInPresentationConfig(
            allowedReceivers: ['approvedTime'],
            allowedWrappers: ['TimeContract.*', 'formatWithApprovedTime'],
          ),
        ),
        relativeFilePath: 'lib/ui/profile_widget.dart',
        source: '''
DateTime allowByReceiver(DateTime approvedTime) {
  return approvedTime.toLocal();
}

DateTime allowByWrapper(DateTime utcTimestamp) {
  return TimeContract.normalizeCivilDate(utcTimestamp.toLocal());
}

DateTime allowByTopLevelWrapper(DateTime utcTimestamp) {
  return formatWithApprovedTime(utcTimestamp.toLocal());
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_device_local_in_presentation')),
      );
    });

    test('honours non-default allowed wrappers', () async {
      const config = NoDeviceLocalInPresentationConfig(
        allowedWrappers: ['TimeContract.*'],
      );

      final errors = await _runRule(
        rule: NoDeviceLocalInPresentationLint(config: config),
        relativeFilePath: 'lib/presentation/date_tile.dart',
        source: '''
String render(DateTime utcTimestamp) {
  return TimeContract.formatForUi(utcTimestamp.toLocal());
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_device_local_in_presentation')),
      );
    });

    test('respects include and exclude globs', () async {
      final errors = await _runRule(
        rule: NoDeviceLocalInPresentationLint(
          config: NoDeviceLocalInPresentationConfig(
            includeGlobs: ['**/ui/**'],
            excludeGlobs: ['**/ui/legacy/**'],
          ),
        ),
        relativeFilePath: 'lib/ui/legacy/old_widget.dart',
        source: '''
DateTime render(DateTime utcTimestamp) {
  return utcTimestamp.toLocal();
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_device_local_in_presentation')),
      );
    });
  });

  group('no_civil_utc_mix_without_helper', () {
    test('reports real civil+instant binary comparison', () async {
      final errors = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(),
        relativeFilePath: 'lib/mappers/task_mapper.dart',
        source: '''
bool hasMismatch(String civilDate, DateTime createdAtUtcDateTime) {
  return civilDate == createdAtUtcDateTime.toIso8601String();
}
''',
      );

      expect(_errorCodes(errors), contains('no_civil_utc_mix_without_helper'));
    });

    test('reports civil and instant interpolation mix', () async {
      final errors = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(),
        relativeFilePath: 'lib/mappers/task_mapper.dart',
        source: '''
String mapLabel(String civilDate, DateTime createdAtUtcDateTime) {
  return 'civil=\$civilDate instant=\$createdAtUtcDateTime';
}
''',
      );

      expect(_errorCodes(errors), contains('no_civil_utc_mix_without_helper'));
    });

    test('does not report when approved helper is used', () async {
      final errors = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(
          config: NoCivilUtcMixWithoutHelperConfig(
            helperWhitelist: ['TimeContract.normalizeCivilDate'],
          ),
        ),
        relativeFilePath: 'lib/formatters/task_formatter.dart',
        source: '''
String normalize(String civilDate, DateTime createdAtUtcDateTime) {
  return TimeContract.normalizeCivilDate(civilDate, createdAtUtcDateTime);
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_civil_utc_mix_without_helper')),
      );
    });

    test('does not report passthrough wrapper delegation', () async {
      final errors = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(),
        relativeFilePath: 'lib/adapters/task_adapter.dart',
        source: '''
Future<void> saveTask(
  String civilDate,
  DateTime timestampUtcDateTime,
) async {
  return repository.saveTask(civilDate, timestampUtcDateTime);
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_civil_utc_mix_without_helper')),
      );
    });

    test('does not report tests by default exclude globs', () async {
      final errors = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(),
        relativeFilePath: 'test/task_mapper_test.dart',
        source: '''
String mapLabel(String civilDate, DateTime createdAtUtcDateTime) {
  return 'civil=\$civilDate instant=\$createdAtUtcDateTime';
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_civil_utc_mix_without_helper')),
      );
    });

    test('does not report formatter with single timestamp', () async {
      final errors = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(),
        relativeFilePath: 'lib/formatters/task_formatter.dart',
        source: '''
String formatTimestamp(DateTime createdAtUtcDateTime) {
  return DateFormat('yyyy-MM-dd').format(createdAtUtcDateTime);
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_civil_utc_mix_without_helper')),
      );
    });

    test('strict mode off keeps non-risky mixed invocation silent', () async {
      final errors = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(),
        relativeFilePath: 'lib/adapters/adapter.dart',
        source: '''
String merge(String civilDate, DateTime timestampUtcDateTime) {
  return normalizePair(civilDate, timestampUtcDateTime);
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_civil_utc_mix_without_helper')),
      );
    });

    test('strict mode reports non-risky mixed invocation', () async {
      final errors = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(
          config: NoCivilUtcMixWithoutHelperConfig(strictMode: true),
        ),
        relativeFilePath: 'lib/adapters/adapter.dart',
        source: '''
String merge(String civilDate, DateTime timestampUtcDateTime) {
  return normalizePair(civilDate, timestampUtcDateTime);
}
''',
      );

      expect(_errorCodes(errors), contains('no_civil_utc_mix_without_helper'));
    });

    test('honours non-default include and exclude globs', () async {
      const config = NoCivilUtcMixWithoutHelperConfig(
        includeGlobs: ['**/repositories/**'],
        excludeGlobs: ['**/repositories/legacy/**'],
      );

      final positive = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(config: config),
        relativeFilePath: 'lib/repositories/task_repository.dart',
        source: '''
bool compare(String civilDate, DateTime timestampUtcDateTime) {
  return civilDate == timestampUtcDateTime.toIso8601String();
}
''',
      );

      final excluded = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(config: config),
        relativeFilePath: 'lib/repositories/legacy/task_repository.dart',
        source: '''
bool compare(String civilDate, DateTime timestampUtcDateTime) {
  return civilDate == timestampUtcDateTime.toIso8601String();
}
''',
      );

      expect(
        _errorCodes(positive),
        contains('no_civil_utc_mix_without_helper'),
      );
      expect(
        _errorCodes(excluded),
        isNot(contains('no_civil_utc_mix_without_helper')),
      );
    });

    test('smoke fixture representative flow', () async {
      final noLocalErrors = await _runRule(
        rule: NoDeviceLocalInPresentationLint(),
        relativeFilePath: 'lib/presentation/dashboard.dart',
        source: '''
DateTime render(DateTime utcTimestamp) => utcTimestamp.toLocal();
''',
      );
      final mixErrors = await _runRule(
        rule: NoCivilUtcMixWithoutHelperLint(),
        relativeFilePath: 'lib/mappers/dashboard_mapper.dart',
        source: '''
String makeLabel(String civilDate, DateTime timestampUtcDateTime) {
  return 'd=\$civilDate i=\$timestampUtcDateTime';
}
''',
      );

      expect(
        _errorCodes(noLocalErrors),
        contains('no_device_local_in_presentation'),
      );
      expect(
        _errorCodes(mixErrors),
        contains('no_civil_utc_mix_without_helper'),
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
  mustResolve: false,
);

Set<String> _errorCodes(List<Diagnostic> errors) {
  return errors.map((error) => error.diagnosticCode.lowerCaseName).toSet();
}

// ignore_for_file: deprecated_member_use

import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:dart_architecture_lints/no_utc_time_format_without_empresa_helper.dart';
import 'package:test/test.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

import 'rule_test_support.dart';

void main() {
  group('no_utc_time_format_without_empresa_helper', () {
    // -------------------------------------------------------------------------
    // Cases that MUST be flagged
    // -------------------------------------------------------------------------

    test('flags DateFormat time-pattern .format() with raw UTC arg', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/incident_tile.dart',
        source: '''
import 'package:intl/intl.dart';
String formatStart(DateTime timestampUtc) {
  return DateFormat('HH:mm').format(timestampUtc);
}
''',
      );

      expect(
        _errorCodes(errors),
        contains('no_utc_time_format_without_empresa_helper'),
      );
    });

    test('flags HH:mm:ss pattern with raw model field', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/widgets/schedule_row.dart',
        source: '''
import 'package:intl/intl.dart';
String render(dynamic model) {
  return DateFormat('HH:mm:ss').format(model.timestampPropuestoDateTime);
}
''',
      );

      expect(
        _errorCodes(errors),
        contains('no_utc_time_format_without_empresa_helper'),
      );
    });

    test('flags 12-hour h:mm a pattern', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/screens/admin_screen.dart',
        source: '''
import 'package:intl/intl.dart';
String display(DateTime ts) => DateFormat('h:mm a').format(ts);
''',
      );

      expect(
        _errorCodes(errors),
        contains('no_utc_time_format_without_empresa_helper'),
      );
    });

    test(
      'flags DateFormat.Hm() named constructor without approved wrapper',
      () async {
        final errors = await _runRule(
          rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
          relativeFilePath: 'lib/presentation/time_chip.dart',
          source: '''
import 'package:intl/intl.dart';
String chip(DateTime ts) => DateFormat.Hm().format(ts);
''',
        );

        expect(
          _errorCodes(errors),
          contains('no_utc_time_format_without_empresa_helper'),
        );
      },
    );

    test('flags time-signal variable name as formatter', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/detail_sheet.dart',
        source: '''
import 'package:intl/intl.dart';
final timeFormatter = DateFormat('HH:mm');
String show(DateTime ts) => timeFormatter.format(ts);
''',
      );

      expect(
        _errorCodes(errors),
        contains('no_utc_time_format_without_empresa_helper'),
      );
    });

    // -------------------------------------------------------------------------
    // Cases that MUST NOT be flagged
    // -------------------------------------------------------------------------

    test(
      'does not flag when argument is wrapped by toEmpresaLocalTime',
      () async {
        final errors = await _runRule(
          rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
          relativeFilePath: 'lib/presentation/incident_tile.dart',
          source: '''
import 'package:intl/intl.dart';
String formatStart(dynamic empresaTimeService, DateTime timestampUtc) {
  return DateFormat('HH:mm').format(
    empresaTimeService.toEmpresaLocalTime(timestampUtc),
  );
}
''',
        );

        expect(
          _errorCodes(errors),
          isNot(contains('no_utc_time_format_without_empresa_helper')),
        );
      },
    );

    test('does not flag EmpresaDateTimeFormatter.* wrapper', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/widgets/range_chip.dart',
        source: '''
import 'package:intl/intl.dart';
String display(dynamic dt) {
  return DateFormat('HH:mm').format(EmpresaDateTimeFormatter.formatCivilDate(dt));
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
      );
    });

    test('does not flag date-only format string (dd/MM/yyyy)', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/date_label.dart',
        source: '''
import 'package:intl/intl.dart';
String formatDate(DateTime fechaCivil) {
  return DateFormat('dd/MM/yyyy').format(fechaCivil);
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
      );
    });

    test('does not flag yyyy-MM-dd date-only pattern', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/widgets/calendar_cell.dart',
        source: '''
import 'package:intl/intl.dart';
String formatDate(DateTime civil) => DateFormat('yyyy-MM-dd').format(civil);
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
      );
    });

    test('does not flag outside included globs (domain layer)', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/domain/services/time_service.dart',
        source: '''
import 'package:intl/intl.dart';
String format(DateTime ts) => DateFormat('HH:mm').format(ts);
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
      );
    });

    test('does not flag in test files (default exclude)', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'test/presentation/incident_tile_test.dart',
        source: '''
import 'package:intl/intl.dart';
String formatStart(DateTime timestampUtc) {
  return DateFormat('HH:mm').format(timestampUtc);
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
      );
    });

    test('respects non-default include and exclude globs', () async {
      const config = NoUtcTimeFormatConfig(
        includeGlobs: ['**/admin/**'],
        excludeGlobs: ['**/admin/legacy/**'],
        allowedWrappers: ['*.toEmpresaLocalTime'],
      );

      final flagged = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(config: config),
        relativeFilePath: 'lib/admin/incident_admin.dart',
        source: '''
import 'package:intl/intl.dart';
String display(DateTime ts) => DateFormat('HH:mm').format(ts);
''',
      );

      final excluded = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(config: config),
        relativeFilePath: 'lib/admin/legacy/incident_admin.dart',
        source: '''
import 'package:intl/intl.dart';
String display(DateTime ts) => DateFormat('HH:mm').format(ts);
''',
      );

      expect(
        _errorCodes(flagged),
        contains('no_utc_time_format_without_empresa_helper'),
      );
      expect(
        _errorCodes(excluded),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
      );
    });

    test('respects non-default allowed wrappers', () async {
      const config = NoUtcTimeFormatConfig(
        allowedWrappers: ['MyTimeHelper.convert'],
      );

      final approved = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(config: config),
        relativeFilePath: 'lib/presentation/custom_tile.dart',
        source: '''
import 'package:intl/intl.dart';
String show(DateTime ts) {
  return DateFormat('HH:mm').format(MyTimeHelper.convert(ts));
}
''',
      );

      final rejected = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(config: config),
        relativeFilePath: 'lib/presentation/other_tile.dart',
        source: '''
import 'package:intl/intl.dart';
String show(DateTime ts) {
  return DateFormat('HH:mm').format(ts);
}
''',
      );

      expect(
        _errorCodes(approved),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
      );
      expect(
        _errorCodes(rejected),
        contains('no_utc_time_format_without_empresa_helper'),
      );
    });

    test('does not flag DateFormat.jm() when argument goes through approved helper', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/screens/time_screen.dart',
        source: '''
import 'package:intl/intl.dart';
String render(dynamic svc, DateTime ts) {
  return DateFormat.jm().format(svc.toEmpresaLocalTime(ts));
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
      );
    });

    // -------------------------------------------------------------------------
    // Variable-alias detection (Phase 1 pre-scan)
    // -------------------------------------------------------------------------

    test('flags aliased formatter variable with generic name (f) calling format without wrapper', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/incident_tile.dart',
        source: '''
import 'package:intl/intl.dart';
String formatStart(DateTime rawTimestampUtc) {
  final f = DateFormat('HH:mm');
  return f.format(rawTimestampUtc);
}
''',
      );

      expect(
        _errorCodes(errors),
        contains('no_utc_time_format_without_empresa_helper'),
        reason:
            'Variable f is initialized with a time DateFormat — '
            'should be flagged regardless of its generic name',
      );
    });

    test(
      'does not flag aliased formatter when format arg is approved wrapper',
      () async {
        final errors = await _runRule(
          rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
          relativeFilePath: 'lib/presentation/incident_tile.dart',
          source: '''
import 'package:intl/intl.dart';
String formatStart(dynamic svc, DateTime rawTs) {
  final f = DateFormat('HH:mm');
  return f.format(svc.toEmpresaLocalTime(rawTs));
}
''',
        );

        expect(
          _errorCodes(errors),
          isNot(contains('no_utc_time_format_without_empresa_helper')),
          reason: 'Argument is wrapped by toEmpresaLocalTime — should pass',
        );
      },
    );

    test(
      'does not flag aliased formatter initialized with date-only pattern',
      () async {
        final errors = await _runRule(
          rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
          relativeFilePath: 'lib/presentation/date_label.dart',
          source: '''
import 'package:intl/intl.dart';
String format(DateTime civil) {
  final f = DateFormat('dd/MM/yyyy');
  return f.format(civil);
}
''',
        );

        expect(
          _errorCodes(errors),
          isNot(contains('no_utc_time_format_without_empresa_helper')),
          reason: 'Format string has no hour specifier — variable should not be tracked',
        );
      },
    );

    test(
      'flags aliased DateFormat.Hm() assigned to generic variable name',
      () async {
        final errors = await _runRule(
          rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
          relativeFilePath: 'lib/widgets/schedule_row.dart',
          source: '''
import 'package:intl/intl.dart';
String render(DateTime ts) {
  final fmt = DateFormat.Hm();
  return fmt.format(ts);
}
''',
        );

        expect(
          _errorCodes(errors),
          contains('no_utc_time_format_without_empresa_helper'),
          reason: 'fmt is initialized with DateFormat.Hm() — must be detected by collector',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Pre-converted local variable (Phase-1 collector — preConvertedVars)
    // -------------------------------------------------------------------------

    test(
      'does not flag when arg is local var initialized from toEmpresaLocalTime',
      () async {
        final errors = await _runRule(
          rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
          relativeFilePath: 'lib/presentation/incident_tile.dart',
          source: '''
import 'package:intl/intl.dart';
String render(dynamic svc, DateTime rawTs) {
  final f = DateFormat('HH:mm');
  final local = svc.toEmpresaLocalTime(rawTs);
  return f.format(local);
}
''',
        );

        expect(
          _errorCodes(errors),
          isNot(contains('no_utc_time_format_without_empresa_helper')),
          reason:
              'local was initialized from toEmpresaLocalTime — pre-converted',
        );
      },
    );

    test('does not flag when arg is local var assigned from toEmpresaLocalTime '
        '(separate declaration and assignment)', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/detail_sheet.dart',
        source: '''
import 'package:intl/intl.dart';
String render(dynamic svc, DateTime rawTs) {
  final f = DateFormat('HH:mm');
  DateTime local;
  local = svc.toEmpresaLocalTime(rawTs);
  return f.format(local);
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
        reason: 'local was assigned from toEmpresaLocalTime — pre-converted',
      );
    });

    test(
      'still flags when arg is raw variable (not from approved wrapper)',
      () async {
        final errors = await _runRule(
          rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
          relativeFilePath: 'lib/presentation/incident_tile.dart',
          source: '''
import 'package:intl/intl.dart';
String render(DateTime rawTs) {
  final f = DateFormat('HH:mm');
  return f.format(rawTs);
}
''',
        );

        expect(
          _errorCodes(errors),
          contains('no_utc_time_format_without_empresa_helper'),
          reason: 'rawTs is not pre-converted — must still be flagged',
        );
      },
    );

    // -------------------------------------------------------------------------
    // allow_utc_debug_context option
    // -------------------------------------------------------------------------

    test('does not flag format inside UTC-labeled interpolation '
        'when the UTC debug context is allowed', () async {
      const config = NoUtcTimeFormatConfig(allowUtcDebugContext: true);

      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(config: config),
        relativeFilePath: 'lib/presentation/debug_tile.dart',
        source: r'''
import 'package:intl/intl.dart';
String debugLabel(DateTime ts) {
  final fmt = DateFormat('HH:mm');
  return '${fmt.format(ts)} UTC';
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
        reason: 'String interpolation contains literal UTC — debug context',
      );
    });

    test(
      'still flags bare format call even when the UTC debug context is allowed',
      () async {
        const config = NoUtcTimeFormatConfig(allowUtcDebugContext: true);

        final errors = await _runRule(
          rule: NoUtcTimeFormatWithoutEmpresaHelperLint(config: config),
          relativeFilePath: 'lib/presentation/admin_tile.dart',
          source: '''
import 'package:intl/intl.dart';
String display(DateTime ts) {
  final fmt = DateFormat('HH:mm');
  return fmt.format(ts);
}
''',
        );

        expect(
          _errorCodes(errors),
          contains('no_utc_time_format_without_empresa_helper'),
          reason: 'No UTC label in interpolation — must still be flagged',
        );
      },
    );

    test('does not flag with allow_utc_debug_context false by default even with UTC string', () async {
      // With default config (allow_utc_debug_context: false), the UTC string
      // context does NOT silence the rule.
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/debug_tile.dart',
        source: r'''
import 'package:intl/intl.dart';
String debugLabel(DateTime ts) {
  final fmt = DateFormat('HH:mm');
  return '${fmt.format(ts)} UTC';
}
''',
      );

      expect(
        _errorCodes(errors),
        contains('no_utc_time_format_without_empresa_helper'),
        reason: 'allow_utc_debug_context is false by default — UTC label does not silence rule',
      );
    });

    // -------------------------------------------------------------------------
    // Scope-aware resolution — same variable name in multiple functions
    // -------------------------------------------------------------------------

    test('scope isolation: same variable name in two functions — '
        'converted in A passes, raw in B fails', () async {
      // Both functions share the variable name `local`.
      // The rule must resolve each usage against its own function scope.
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/scope_isolation.dart',
        source: r'''
import 'package:intl/intl.dart';
final f = DateFormat('HH:mm');

// fnA: local is pre-converted — should NOT be flagged.
String fnA(dynamic svc, DateTime ts) {
  final local = svc.toEmpresaLocalTime(ts);
  return f.format(local);
}

// fnB: local is raw — MUST be flagged.
String fnB(DateTime ts) {
  final local = ts;
  return f.format(local);
}
''',
      );

      // Only fnB produces an error.
      expect(
        errors,
        hasLength(1),
        reason: 'Only fnB.local (raw) must be flagged; fnA.local (converted) must pass',
      );
      expect(
        _errorCodes(errors),
        contains('no_utc_time_format_without_empresa_helper'),
      );
    });

    test('scope isolation: same variable name in two methods — '
        'no cross-function pollution', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/my_widget.dart',
        source: r'''
import 'package:intl/intl.dart';

class MyWidget {
  final fmt = DateFormat('HH:mm');

  // methodA: local is pre-converted — must NOT be flagged.
  String methodA(dynamic svc, DateTime ts) {
    final local = svc.toEmpresaLocalTime(ts);
    return fmt.format(local);
  }

  // methodB: local is raw — MUST be flagged.
  String methodB(DateTime ts) {
    final local = ts;
    return fmt.format(local);
  }
}
''',
      );

      expect(
        errors,
        hasLength(1),
        reason: 'Only methodB.local (raw) must be flagged; methodA.local (converted) must pass',
      );
    });

    // -------------------------------------------------------------------------
    // Scope-aware resolution — nested blocks
    // -------------------------------------------------------------------------

    test('nested scope: inner raw variable shadows outer converted — '
        'inner call is flagged', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/nested_scope.dart',
        source: r'''
import 'package:intl/intl.dart';
final f = DateFormat('HH:mm');

String display(dynamic svc, DateTime ts) {
  final local = svc.toEmpresaLocalTime(ts); // outer — converted
  {
    final local = ts;      // inner — raw, shadows outer
    return f.format(local); // FAIL: resolves to inner raw local
  }
}
''',
      );

      expect(
        errors,
        hasLength(1),
        reason: 'Inner raw local shadows outer converted — must be flagged',
      );
    });

    test('nested scope: no shadowing — outer converted variable is visible '
        'inside inner block', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/nested_pass.dart',
        source: r'''
import 'package:intl/intl.dart';
final f = DateFormat('HH:mm');

String display(dynamic svc, DateTime ts) {
  final local = svc.toEmpresaLocalTime(ts); // outer — converted
  if (ts.isUtc) {
    return f.format(local); // PASS: no inner shadow, resolves to outer converted
  }
  return '';
}
''',
      );

      expect(
        _errorCodes(errors),
        isNot(contains('no_utc_time_format_without_empresa_helper')),
        reason: 'Outer converted local visible inside if-block — must not be flagged',
      );
    });

    test('nested scope: reassignment in inner block to raw shadows outer '
        'converted assignment', () async {
      final errors = await _runRule(
        rule: NoUtcTimeFormatWithoutEmpresaHelperLint(),
        relativeFilePath: 'lib/presentation/reassign_scope.dart',
        source: r'''
import 'package:intl/intl.dart';
final f = DateFormat('HH:mm');

String display(dynamic svc, DateTime ts) {
  DateTime local;
  local = svc.toEmpresaLocalTime(ts); // outer assignment — converted
  {
    local = ts; // inner reassignment — raw (overwrites)
    return f.format(local); // FAIL: last assignment in scope chain is raw
  }
}
''',
      );

      expect(
        errors,
        hasLength(1),
        reason: 'Last assignment of local before format call is raw — must be flagged',
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

// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/enforce_final_variables.dart';
import 'package:dart_architecture_lints/avoid_unawaited.dart';
import 'package:dart_architecture_lints/logger_context_must_be_structured.dart';
import 'package:dart_architecture_lints/no_result_throw.dart';
import 'package:dart_architecture_lints/no_sensitive_data_in_log_metadata.dart';
import 'package:dart_architecture_lints/enforce_utc_dates.dart';
import 'package:dart_architecture_lints/logger_context_matches_scope.dart';
import 'package:dart_architecture_lints/method_order_rule.dart';
import 'package:dart_architecture_lints/mixin_no_state_ownership.dart';
import 'package:dart_architecture_lints/multiprovider_order.dart';
import 'package:dart_architecture_lints/no_datetime_now.dart';
import 'package:dart_architecture_lints/no_static_map_controllers.dart';
import 'package:dart_architecture_lints/require_explicit_types.dart';
import 'package:dart_architecture_lints/require_keys_in_lists.dart';
import 'package:dart_architecture_lints/streamcontroller_must_close.dart';
import 'package:dart_architecture_lints/time_scope.dart';
import 'package:dart_architecture_lints/variable_name_should_match_class_name.dart';
import 'package:test/test.dart';
import 'rule_test_support.dart';

void main() {
  test(
    'final: reassignment, compound writes, closures and shadowing resolve',
    () async {
      final errors = await runRule(const EnforceFinalVariablesLint(), '''
void run() {
  var count = 0;
  count++;
  var sum = 0;
  sum += count;
  var captured = 0;
  void change() { captured = sum; }
  change();
  var unchanged = 1;
  { var unchanged = 2; unchanged++; print(unchanged); }
  print([count, sum, captured, unchanged]);
}
''');
      expect(errors, hasLength(1));
    },
  );

  test('resolved inferred maps and mixin resources stay detected', () async {
    const source = '''
import 'dart:async';
class Cache { static final timers = <String, Timer>{}; }
mixin Scheduling { final timer = Timer(Duration.zero, () {}); }
''';
    expect(
      await runRule(const NoStaticMapControllersLint(), source),
      hasLength(1),
    );
    expect(
      await runRule(const MixinNoStateOwnershipLint(), source),
      hasLength(1),
    );
  });

  test(
    'legacy async justification and no-throw contracts remain effective',
    () async {
      expect(
        await runRule(const AvoidUnawaitedLint(), '''
import 'dart:async';
Future<void> cleanup() async {}
void run() {
  unawaited(cleanup());
  // unawaited-ok: best-effort-cleanup - independent no-throw cleanup
  unawaited(cleanup());
}
'''),
        hasLength(1),
      );
      expect(
        await runRule(const NoResultThrowLint(), '''
class RecordRepository {
  int fetch() { throw StateError('unavailable'); }
  int cached() => 1;
}
'''),
        hasLength(1),
      );
    },
  );

  test(
    'legacy structured context and sensitive metadata remain effective',
    () async {
      const source = '''
class DiagnosticsLoggerService {
  static void warning(String message, {String? context, Map<String, String>? metadata}) {}
}
void run() {
  DiagnosticsLoggerService.warning('operation failed', metadata: {'token': 'fixture'});
  DiagnosticsLoggerService.warning('operation failed', context: 'Sample.run', metadata: {'requestId': 'fixture'});
}
''';
      expect(
        await runRule(const LoggerContextMustBeStructuredLint(), source),
        hasLength(1),
      );
      expect(
        await runRule(const NoSensitiveDataInLogMetadataLint(), source),
        hasLength(1),
      );
    },
  );

  group('stream ownership and normal exits', () {
    const prelude = '''
import 'dart:async';
class ChangeNotifier { void dispose() {} }
''';
    Future<List<AnalysisError>> check(String body) =>
        runRule(const StreamControllerMustClose(), '$prelude\n$body');

    test('each variable must close, including inferred fields', () async {
      expect(
        await check('''
class Owner extends ChangeNotifier {
  final first = StreamController<int>(), second = StreamController<int>();
  @override void dispose() { first.close(); }
}
'''),
        hasLength(1),
      );
    });
    test('one branch and early return do not prove closure', () async {
      for (final cleanup in [
        'if (flag) controller.close();',
        'if (flag) return; controller.close();',
      ]) {
        expect(
          await check('''
class Owner extends ChangeNotifier {
  final controller = StreamController<int>();
  bool flag = false;
  @override void dispose() { $cleanup }
}
'''),
          hasLength(1),
        );
      }
    });
    test('both branches and finally on return prove closure', () async {
      for (final cleanup in [
        'if (flag) controller.close(); else this.controller.close();',
        'try { if (flag) return; } finally { controller.close(); }',
      ]) {
        expect(
          await check('''
class Owner extends ChangeNotifier {
  final controller = StreamController<int>();
  bool flag = false;
  @override void dispose() { $cleanup }
}
'''),
          isEmpty,
        );
      }
    });
    test('resolved helper cleanup is accepted', () async {
      expect(
        await check('''
class Owner extends ChangeNotifier {
  final controller = StreamController<int>();
  @override void dispose() { _cleanup(); super.dispose(); }
  void _cleanup() { controller.close(); }
}
'''),
        isEmpty,
      );
    });
    test('shadowed controller is not the owned field', () async {
      expect(
        await check('''
class Owner extends ChangeNotifier {
  final controller = StreamController<int>();
  @override void dispose() { final controller = StreamController<int>(); controller.close(); }
}
'''),
        hasLength(1),
      );
    });
    test(
      'borrowed fields and inherited ownership are not disposed by child',
      () async {
        expect(
          await check('''
class Parent extends ChangeNotifier {
  final controller = StreamController<int>();
  @override void dispose() { controller.close(); super.dispose(); }
}
class Child extends Parent { }
class Borrower extends ChangeNotifier {
  Borrower(this.controller);
  final StreamController<int> controller;
}
'''),
          isEmpty,
        );
      },
    );
    test('constructor-owned resource requires cleanup', () async {
      expect(
        await check('''
class Owner extends ChangeNotifier {
  Owner() : controller = StreamController<int>();
  final StreamController<int> controller;
}
'''),
        hasLength(1),
      );
    });
    test('same-named non-SDK controller is not a stream resource', () async {
      expect(
        await runRule(const StreamControllerMustClose(), '''
class StreamController<T> {}
class ChangeNotifier { void dispose() {} }
class Owner extends ChangeNotifier { final controller = StreamController<int>(); }
'''),
        isEmpty,
      );
    });
    test('try cleanup cannot cover catch normal exit', () async {
      expect(
        await check('''
class Owner extends ChangeNotifier {
  final controller = StreamController<int>();
  @override void dispose() { try { controller.close(); } catch (_) { } }
}
'''),
        hasLength(1),
      );
    });
    test('unawaited async helper does not establish cleanup', () async {
      expect(
        await check('''
class Owner extends ChangeNotifier {
  final controller = StreamController<int>();
  @override void dispose() { _cleanup(); }
  Future<void> _cleanup() async { await Future<void>.value(); await controller.close(); }
}
'''),
        hasLength(1),
      );
    });
  });

  test(
    'strict typing remains default; selective accepts obvious locals',
    () async {
      const source = '''
class Sample {
  final _count = 0;
  final count = 0;
  int measure(int input) { final result = input + _count; return result; }
}
''';
      expect(await runRule(const RequireExplicitTypes(), source), hasLength(3));
      expect(
        await runRule(const RequireExplicitTypes(policy: 'selective'), source),
        hasLength(1),
      );
    },
  );
  test(
    'selective public signatures, dynamic and named local boundaries',
    () async {
      expect(
        await runRule(
          const RequireExplicitTypes(
            policy: 'selective',
            localNames: ['boundary'],
          ),
          '''
dynamic read() => 1;
class Sample {
  compute(input) {
    final uncertain = read();
    final boundary = 1;
    final obvious = 2;
    return [input, uncertain, boundary, obvious];
  }
}
''',
        ),
        hasLength(4),
      );
    },
  );

  test(
    'UTC parse accepts explicit Z/offset, epoch getters are zone-independent',
    () async {
      expect(
        await runRule(const EnforceUtcDatesLint(), '''
int epoch(DateTime value) => value.millisecondsSinceEpoch;
DateTime zulu() => DateTime.parse('2026-01-01T10:00:00Z');
DateTime offset() => DateTime.parse('2026-01-01T10:00:00+02:00');
DateTime local() => DateTime.parse('2026-01-01T10:00:00');
DateTime converted() => DateTime(2026).toUtc();
DateTime now() => DateTime.now();
''', path: 'lib/data/time.dart'),
        hasLength(2),
      );
    },
  );
  test(
    'civil exception keeps clock restriction; clock exception is scoped',
    () async {
      const source = '''
DateTime civil() => DateTime(2026, 1, 1);
DateTime current() => DateTime.now();
''';
      expect(await runRule(const NoDateTimeNowLint(), source), hasLength(2));
      expect(
        await runRule(
          const NoDateTimeNowLint(
            scope: TimeScope(civilGlobs: ['**/calendar.dart']),
          ),
          source,
          path: 'lib/calendar.dart',
        ),
        hasLength(1),
      );
      expect(
        await runRule(
          const NoDateTimeNowLint(
            scope: TimeScope(clockGlobs: ['**/clock.dart']),
          ),
          source,
          path: 'lib/clock.dart',
        ),
        hasLength(1),
      );
      expect(
        await runRule(
          const EnforceUtcDatesLint(
            scope: TimeScope(civilGlobs: ['**/calendar.dart']),
          ),
          source,
          path: 'lib/data/calendar.dart',
        ),
        hasLength(1),
      );
    },
  );
  test(
    'date checks resolve SDK symbols and accept explicitly offset parses',
    () async {
      const source = '''
import 'dart:core' as core;
core.DateTime current() => core.DateTime.now();
core.DateTime local() => core.DateTime(2026);
core.DateTime offset() => core.DateTime.parse('2026-01-01T10:00:00+02:00');
''';
      expect(await runRule(const NoDateTimeNowLint(), source), hasLength(2));
      expect(
        await runRule(
          const EnforceUtcDatesLint(),
          source,
          path: 'lib/data/dates.dart',
        ),
        hasLength(2),
      );
    },
  );
  test('logger names, scope and argument are configurable', () async {
    const source = '''
class Logger { static void warn({required String scope}) {} }
class Sample {
  void run() { Logger.warn(scope: 'Sample.wrong'); }
}
''';
    expect(
      await runRule(const LoggerContextMatchesScopeLint(), source),
      isEmpty,
    );
    expect(
      await runRule(
        const LoggerContextMatchesScopeLint(
          includeGlobs: ['**/lib/**'],
          loggerNames: ['Logger'],
          methods: ['warn'],
          contextArgument: 'scope',
        ),
        source,
      ),
      hasLength(1),
    );
  });
  test(
    'provider naming contract still requires state before view model',
    () async {
      const prelude = '''
class PanelUiState {}
class PanelViewModel {}
class Provider<T> { Provider(); }
class MultiProvider { MultiProvider({required List<Object> providers}); }
''';
      for (final (entries, count) in [
        ('Provider<PanelViewModel>(), Provider<PanelUiState>()', 1),
        ('Provider<PanelUiState>(), Provider<PanelViewModel>()', 0),
      ]) {
        expect(
          await runRule(const MultiProviderOrderLint(), '''
$prelude
void compose() { MultiProvider(providers: [$entries]); }
'''),
          hasLength(count),
        );
      }
    },
  );
  test('list key diagnostic is scoped to direct builder returns', () async {
    const source = '''
class Widget {}
class ValueKey { ValueKey(int id); }
class Tile extends Widget { Tile({ValueKey? key}); }
class ListView {
  ListView.builder({required Widget Function(Object, int) itemBuilder});
}
void build() {
  const List<int> ids = [11, 12];
  ListView.builder(itemBuilder: (context, index) => Tile());
  ListView.builder(itemBuilder: (context, index) => Tile(key: ValueKey(ids[index])));
}
''';
    final rule = const RequireKeysInListsLint();
    expect(await runRule(rule, source), hasLength(1));
    expect(rule.code.correctionMessage, contains('stable ValueKey'));
    expect(rule.code.problemMessage, contains('do not prevent rebuilds'));
  });
  test('selected naming and getter-first method order remain strict', () async {
    expect(
      await runRule(const VariableNameShouldMatchClassName(), '''
class RecordModel {}
void run() { final RecordModel value = RecordModel(); print(value); }
'''),
      hasLength(1),
    );
    expect(
      await runRule(const MethodOrderRule(), '''
class Sample { void run() {} int get count => 0; }
'''),
      hasLength(1),
    );
    const accepted = '''
class RecordModel {
  int get count => 0;
  @override String toString() => 'record';
  int measure() { final recordModel = RecordModel(); return recordModel.count; }
}
''';
    for (final rule in [
      const MethodOrderRule(),
      const VariableNameShouldMatchClassName(),
      const RequireExplicitTypes(policy: 'selective'),
    ]) {
      expect(await runRule(rule, accepted), isEmpty);
    }
  });
}

import 'rule_cases.dart';

const _screen = 'lib/presentation/screens/record_screen.dart';
const _widget = 'lib/presentation/widgets/record_tile.dart';

const _logger = '''
class AppLoggerService {
  static void error(String message, {String? context}) {}
}''';

const _diagnostics = '''
class DiagnosticsLoggerService {
  static void warning(String message, {String? context, Map<String, String>? metadata}) {}
}''';

const _overlay = '''
class BuildContext {}
class TextEditingController { void dispose() {} }
class TextField { TextField({Object? controller}); }
Future<T?> showDialog<T>({
  required BuildContext context,
  required Object Function(BuildContext) builder,
}) async => null;''';

const _routes = '''
class GoRoute { GoRoute({Object? builder}); }
class StatelessWidget {}''';

/// Hand-written cases for logging, time, async and presentation rules.
const moreRuleCases = <RuleCase>[
  RuleCase('logger_context_matches_scope', 1, '''
$_logger
class SyncService {
  void push() { AppLoggerService.error('failed', context: 'SyncService.pull'); }
}
''', path: 'lib/data/sync_service.dart'),
  RuleCase('logger_context_matches_scope', 0, '''
$_logger
class SyncService {
  void push() { AppLoggerService.error('failed', context: 'SyncService.push'); }
}
''', path: 'lib/data/sync_service.dart'),
  RuleCase(
    'no_device_local_in_presentation',
    1,
    'String label(DateTime at) => at.toLocal().toString();\n',
    path: _widget,
  ),
  RuleCase(
    'no_device_local_in_presentation',
    0,
    'String label(DateTime at) => at.toUtc().toString();\n',
    path: _widget,
  ),
  RuleCase('no_utc_time_format_without_empresa_helper', 1, '''
import 'package:intl/intl.dart';
String formatStart(DateTime timestampUtc) {
  return DateFormat('HH:mm').format(timestampUtc);
}
''', path: _widget),
  RuleCase('no_utc_time_format_without_empresa_helper', 0, '''
import 'package:intl/intl.dart';
String formatDay(DateTime timestampUtc) {
  return DateFormat('dd/MM/yyyy').format(timestampUtc);
}
''', path: _widget),
  RuleCase('avoid_unawaited', 1, '''
import 'dart:async';
Future<void> cleanup() async {}
void run() { unawaited(cleanup()); }
'''),
  RuleCase('avoid_unawaited', 0, '''
import 'dart:async';
Future<void> cleanup() async {}
void run() {
  // unawaited-ok: best-effort-cleanup - independent no-throw cleanup
  unawaited(cleanup());
}
'''),
  RuleCase('avoid_async_in_provider_create', 1, '''
import 'dart:async';
class Provider { Provider({Object? Function(Object)? create}); }
Future<void> load() async {}
final provider = Provider(create: (_) { unawaited(load()); return 1; });
'''),
  RuleCase('avoid_async_in_provider_create', 0, '''
import 'dart:async';
Future<void> load() async {}
void start() { unawaited(load()); }
'''),
  RuleCase('avoid_async_wrapper_hides_unawaited', 1, '''
Future<void> load() async {}
void start() { Future(() async { await load(); }); }
'''),
  RuleCase('avoid_async_wrapper_hides_unawaited', 0, '''
Future<void> load() async {}
void start() { Future(() async { await load(); await load(); }); }
'''),
  RuleCase('logger_context_must_be_structured', 1, '''
$_diagnostics
void run() { DiagnosticsLoggerService.warning('operation failed'); }
'''),
  RuleCase('logger_context_must_be_structured', 0, '''
$_diagnostics
void run() {
  DiagnosticsLoggerService.warning('operation failed', context: 'Sample.run');
}
'''),
  RuleCase('no_sensitive_data_in_log_metadata', 1, '''
$_diagnostics
void run() {
  DiagnosticsLoggerService.warning('failed', metadata: {'token': 'fixture'});
}
'''),
  RuleCase('no_sensitive_data_in_log_metadata', 0, '''
$_diagnostics
void run() {
  DiagnosticsLoggerService.warning('failed', metadata: {'requestId': 'fixture'});
}
'''),
  RuleCase('no_raw_exception_message_to_user', 1, '''
class Text { Text(String data); }
void show(Exception error) { Text(error.toString()); }
''', path: _screen),
  RuleCase('no_raw_exception_message_to_user', 0, '''
class Text { Text(String data); }
void show() { Text('Saved'); }
''', path: _screen),
  RuleCase('app_exception_must_define_code', 1, '''
class AppException { AppException({String? code}); }
class NetworkException extends AppException {}
'''),
  RuleCase('app_exception_must_define_code', 0, '''
class AppException { AppException({String? code}); }
class NetworkException extends AppException {
  NetworkException() : super(code: 'network');
}
'''),
  RuleCase(
    'avoid_scattered_401_handling',
    1,
    'void handle(int statusCode) { if (statusCode == 401) {} }\n',
  ),
  RuleCase(
    'avoid_scattered_401_handling',
    0,
    'void handle(int statusCode) { if (statusCode == 404) {} }\n',
  ),
  RuleCase(
    'top_level_screens_must_use_base_contract',
    1,
    '''
$_routes
class RecordScreen extends StatelessWidget {}
final route = GoRoute(builder: (context, state) => RecordScreen());
''',
    path: 'lib/router.dart',
    files: {
      'lib/screens/base/base_screen.dart':
          'abstract class BaseAuthenticatedScreen {}\n',
    },
  ),
  RuleCase(
    'top_level_screens_must_use_base_contract',
    0,
    '''
import 'screens/base/base_screen.dart';
$_routes
class RecordScreen extends BaseAuthenticatedScreen {}
final route = GoRoute(builder: (context, state) => RecordScreen());
''',
    path: 'lib/router.dart',
    files: {
      'lib/screens/base/base_screen.dart':
          'abstract class BaseAuthenticatedScreen {}\n',
    },
  ),
  RuleCase('no_domain_entities_in_presentation_ui', 1, '''
import 'package:alignment_fixture/domain/entities/entities.dart';
class RecordScreen {}
''', path: _screen),
  RuleCase('no_domain_entities_in_presentation_ui', 0, '''
import 'package:alignment_fixture/presentation/models/record_ui_model.dart';
class RecordScreen {}
''', path: _screen),
  RuleCase('no_hardcoded_color_literal', 1, '''
class Color { const Color(int value); }
const accent = Color(0xFF2196F3);
''', path: _widget),
  RuleCase('no_hardcoded_color_literal', 0, '''
class Color { const Color(int value); }
const accent = Color(0xFF2196F3);
''', path: 'lib/presentation/theme/colors.dart'),
  RuleCase('no_hardcoded_border_radius', 1, '''
class BorderRadius { BorderRadius.circular(double radius); }
final radius = BorderRadius.circular(12);
''', path: _widget),
  RuleCase('no_hardcoded_border_radius', 0, '''
class BorderRadius { BorderRadius.circular(double radius); }
final radius = BorderRadius.circular(10);
''', path: _widget),
  RuleCase('overlay_lifecycle_context_safety', 1, '''
$_overlay
Future<void> open(BuildContext context) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => TextField(controller: controller),
  );
  controller.dispose();
}
''', path: _screen),
  RuleCase('overlay_lifecycle_context_safety', 0, '''
$_overlay
Future<void> open(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => TextField(controller: null),
  );
}
''', path: _screen),
];

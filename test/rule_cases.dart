import 'dart:io';

import 'rule_cases_more.dart';

/// One fixture for one rule: [reports] diagnostics expected in the file at
/// [path] (other package files in [files]). [fence] reads the source from the
/// rule document's Dart fence with that index instead of [source].
class RuleCase {
  const RuleCase(
    this.rule,
    this.reports,
    this.source, {
    this.path = 'lib/example.dart',
    this.files = const {},
  }) : fence = null;

  const RuleCase.doc(
    this.rule,
    this.reports,
    int this.fence, {
    this.path = 'lib/example.dart',
  }) : source = '',
       files = const {};

  final String rule;
  final int reports;
  final String source;
  final int? fence;
  final String path;
  final Map<String, String> files;

  /// The analyzed source.
  String text() {
    final index = fence;
    if (index == null) return source;
    final doc = File('docs/rules/$rule.md').readAsStringSync();
    final fences = RegExp(r'```dart\n([\s\S]*?)```').allMatches(doc).toList();
    return fences[index].group(1)!;
  }

  @override
  String toString() =>
      '$rule: $reports at $path${fence == null ? '' : ' (doc fence $fence)'}';
}

const _entity = 'lib/domain/entities/record_entity.dart';
const _screen = 'lib/presentation/screens/record_screen.dart';
const _viewModel = 'lib/presentation/viewModels/record_view_model.dart';

/// A positive and a negative case for every registered rule. Each rule
/// document's BAD fence fires and its GOOD fence passes where one exists.
final ruleCases = <RuleCase>[
  // Rule documents: BAD fence (0) fires, GOOD fence (1) passes.
  for (final rule in [
    'enforce_final_variables',
    'no_late_keyword',
    'no_bang_operator',
    'method_order',
    'one_class_per_file',
    'viewmodels_no_buildcontext',
    'usecases_follow_pattern',
    'viewmodels_call_super_dispose',
    'viewmodels_no_flutter_types',
    'require_explicit_types',
    'uistate_must_call_super_dispose',
    'no_local_datetime_constructors',
    'no_direct_internet_calls',
    'no_exception_message_passthrough',
  ]) ...[RuleCase.doc(rule, 1, 0), RuleCase.doc(rule, 0, 1)],
  for (final rule in [
    'no_external_dependencies_in_domain',
    'domain_entities_must_use_freezed',
    'no_serialization_in_entities',
    'enforce_utc_dates',
    'no_direct_error_logging_in_data_domain',
  ]) ...[
    RuleCase.doc(rule, 1, 0, path: _entity),
    RuleCase.doc(rule, 0, 1, path: _entity),
  ],
  RuleCase.doc('domain_values_shallow_immutable', 2, 0, path: _entity),
  RuleCase.doc('domain_values_shallow_immutable', 0, 1, path: _entity),
  RuleCase.doc(
    'models_must_have_json_serialization',
    1,
    0,
    path: 'lib/data/models/record_model.dart',
  ),
  RuleCase.doc(
    'models_must_have_json_serialization',
    0,
    1,
    path: 'lib/data/models/record_model.dart',
  ),
  RuleCase.doc('viewmodels_extend_base_viewmodel', 1, 0, path: _viewModel),
  RuleCase.doc('viewmodels_extend_base_viewmodel', 0, 1, path: _viewModel),
  RuleCase.doc(
    'no_civil_utc_mix_without_helper',
    1,
    0,
    path: 'lib/core/mappers/record_mapper.dart',
  ),
  RuleCase(
    'no_civil_utc_mix_without_helper',
    0,
    'DateTime toInstant(DateTime at) => at.toUtc();\n',
    path: 'lib/core/mappers/record_mapper.dart',
  ),
  ...manualCases,
];

/// Hand-written cases for rules whose document has no single-file BAD/GOOD
/// pair that fires at one path.
const manualCases = <RuleCase>[
  // The document shows the plugin-prefixed form, which custom_lint did not
  // read; these use the bare form both implementations check.
  RuleCase('avoid_unawaited_ignore_without_reason', 1, '''
import 'dart:async';
Future<void> cleanup() async {}
void run() {
  // ignore: avoid_unawaited
  unawaited(cleanup());
}
'''),
  RuleCase('avoid_unawaited_ignore_without_reason', 0, '''
import 'dart:async';
Future<void> cleanup() async {}
void run() {
  // ignore-reason: legacy call, migration tracked separately
  // ignore: avoid_unawaited
  unawaited(cleanup());
}
'''),
  RuleCase('variable_name_should_contain_class_name', 1, '''
class RecordModel {}
void run() { final RecordModel value = RecordModel(); print(value); }
'''),
  RuleCase('variable_name_should_contain_class_name', 0, '''
class RecordModel {}
void run() { final RecordModel recordModel = RecordModel(); print(recordModel); }
'''),
  RuleCase(
    'avoid_hardcoded_strings',
    1,
    "String title() => 'Welcome back';\n",
    path: _screen,
  ),
  RuleCase(
    'avoid_hardcoded_strings',
    0,
    "String title() => 'home.title';\n",
    path: _screen,
  ),
  RuleCase('no_result_throw', 1, '''
class RecordRepository {
  int fetch() { throw StateError('unavailable'); }
}
'''),
  RuleCase('no_result_throw', 0, '''
class RecordRepository {
  int fetch() {
    try { throw StateError('unavailable'); } on StateError { return 0; }
  }
}
'''),
  RuleCase(
    'usecases_extend_base_usecase',
    1,
    'class GetRecordUseCase {}\n',
    path: 'lib/domain/useCases/get_record_use_case.dart',
  ),
  RuleCase(
    'usecases_extend_base_usecase',
    0,
    'abstract class BaseUseCase {}\n'
        'class GetRecordUseCase extends BaseUseCase {}\n',
    path: 'lib/domain/useCases/get_record_use_case.dart',
  ),
  RuleCase(
    'repository_methods_return_result',
    1,
    'class RecordRepository { Future<int> load() async => 1; }\n',
    path: 'lib/data/repositories/record_repository.dart',
  ),
  RuleCase('repository_methods_return_result', 0, '''
class Result<T> {}
class RecordRepository { Future<Result<int>> load() async => Result<int>(); }
''', path: 'lib/data/repositories/record_repository.dart'),
  RuleCase('streamcontroller_must_close', 1, '''
import 'dart:async';
class ChangeNotifier { void dispose() {} }
class RecordViewModel extends ChangeNotifier {
  final StreamController<int> controller = StreamController<int>();
}
''', path: _viewModel),
  RuleCase('streamcontroller_must_close', 0, '''
import 'dart:async';
class ChangeNotifier { void dispose() {} }
class RecordViewModel extends ChangeNotifier {
  final StreamController<int> controller = StreamController<int>();
  @override
  void dispose() { controller.close(); super.dispose(); }
}
''', path: _viewModel),
  RuleCase(
    'datasources_return_result',
    1,
    'class RecordDataSource { Future<int> load() async => 1; }\n',
    path: 'lib/data/dataSources/record_data_source.dart',
  ),
  RuleCase('datasources_return_result', 0, '''
class Result<T> {}
class RecordDataSource { Future<Result<int>> load() async => Result<int>(); }
''', path: 'lib/data/dataSources/record_data_source.dart'),
  RuleCase('no_business_logic_in_widgets', 1, '''
class StatelessWidget {}
class GetRecordUseCase {}
class RecordScreen extends StatelessWidget {
  void build() { GetRecordUseCase(); }
}
''', path: _screen),
  RuleCase('no_business_logic_in_widgets', 0, '''
class StatelessWidget {}
class RecordScreen extends StatelessWidget {
  void build() { print('record'); }
}
''', path: _screen),
  RuleCase('no_static_map_controllers', 1, '''
import 'dart:async';
class Cache { static final timers = <String, Timer>{}; }
'''),
  RuleCase('no_static_map_controllers', 0, '''
import 'dart:async';
class Cache { final timers = <String, Timer>{}; }
'''),
  RuleCase('mixin_no_state_ownership', 1, '''
import 'dart:async';
mixin Scheduling { final timer = Timer(Duration.zero, () {}); }
'''),
  RuleCase(
    'mixin_no_state_ownership',
    0,
    'mixin Counting { int count = 0; }\n',
  ),
  RuleCase('multiprovider_order', 1, '''
$_providers
void compose() {
  MultiProvider(providers: [Provider<PanelViewModel>(), Provider<PanelUiState>()]);
}
'''),
  RuleCase('multiprovider_order', 0, '''
$_providers
void compose() {
  MultiProvider(providers: [Provider<PanelUiState>(), Provider<PanelViewModel>()]);
}
'''),
  RuleCase('require_keys_in_lists', 1, '''
$_lists
void build() { ListView.builder(itemBuilder: (context, index) => Tile()); }
'''),
  RuleCase('require_keys_in_lists', 0, '''
$_lists
void build() {
  ListView.builder(itemBuilder: (context, index) => Tile(key: ValueKey(index)));
}
'''),
  ...moreRuleCases,
];

const _providers = '''
class PanelUiState {}
class PanelViewModel {}
class Provider<T> { Provider(); }
class MultiProvider { MultiProvider({required List<Object> providers}); }''';

const _lists = '''
class Widget {}
class ValueKey { ValueKey(int id); }
class Tile extends Widget { Tile({ValueKey? key}); }
class ListView {
  ListView.builder({required Widget Function(Object, int) itemBuilder});
}''';

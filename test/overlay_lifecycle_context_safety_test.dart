import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:dart_architecture_lints/overlay_lifecycle_context_safety.dart';
import 'package:test/test.dart';

import 'rule_test_support.dart';

void main() {
  group('overlay_lifecycle_context_safety (AST)', () {
    // ── Pattern A — captured caller-owned controllers ──────────────────────
    test(
      'A: reports local TextEditingController captured by dialog builder',
      () async {
        final errors = await _runRule('''
Future<void> open(BuildContext context) async {
  final TextEditingController controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) =>
        TextField(controller: controller, autofocus: true),
  );
  controller.dispose();
}
''');
        expect(_codes(errors), contains('overlay_lifecycle_context_safety'));
      },
    );

    test(
      'A: reports inferred local controller captured by sheet builder',
      () async {
        final errors = await _runRule('''
Future<void> open(BuildContext context) async {
  final controller = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    builder: (_) => TextField(controller: controller),
  );
}
''');
        expect(_codes(errors), contains('overlay_lifecycle_context_safety'));
      },
    );

    // ── Pattern B — captured caller BuildContext for inherited lookups ──────
    test(
      'B: reports AppLocalizations.of(callerContext) inside dialog builder',
      () async {
        final errors = await _runRule('''
void open(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => Text(AppLocalizations.of(context)?.title ?? ''),
  );
}
''');
        expect(_codes(errors), contains('overlay_lifecycle_context_safety'));
      },
    );

    test(
      'B: reports context.read<T>() with caller context inside sheet builder',
      () async {
        final errors = await _runRule('''
void open(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => Text('\${context.read<int>()}'),
  );
}
''');
        expect(_codes(errors), contains('overlay_lifecycle_context_safety'));
      },
    );

    test(
      'A: reports local controller captured by MaterialPageRoute builder',
      () async {
        final errors = await _runRule('''
void open(BuildContext context) {
  final controller = TextEditingController();
  final route = MaterialPageRoute<void>(
    builder: (_) => TextField(controller: controller),
  );
  route.builder(context);
}
''');
        expect(_codes(errors), contains('overlay_lifecycle_context_safety'));
      },
    );

    test(
      'FP: showTimePicker builder using its own ctx is not reported',
      () async {
        final errors = await _runRule('''
void open(BuildContext context) {
  showTimePicker(
    context: context,
    builder: (BuildContext ctx, Widget? child) =>
        MediaQuery(data: MediaQuery.of(ctx), child: child),
  );
}
''');
        expect(_codes(errors), isEmpty);
      },
    );

    // ── False positives the textual version produced (must stay clean) ──────
    test('FP: controller owned by State field is not reported', () async {
      final errors = await _runRule('''
class MyState extends State<StatefulWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void open(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => TextField(controller: _controller),
    );
  }
}
''');
      expect(_codes(errors), isEmpty);
    });

    test(
      'FP: builder using its own context parameter is not reported',
      () async {
        final errors = await _runRule('''
void open(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) =>
        Text('\${Theme.of(dialogContext).textTheme.titleMedium}'),
  );
}
''');
        expect(_codes(errors), isEmpty);
      },
    );

    test(
      'FP: ordinary build(context) with Theme.of(context) is not reported',
      () async {
        final errors = await _runRule('''
class Card extends StatelessWidget {
  const Card({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text('\${theme.textTheme.titleMedium}');
  }
}

void open(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) =>
        Text('\${Theme.of(sheetContext).textTheme.bodyMedium}'),
  );
}
''');
        expect(_codes(errors), isEmpty);
      },
    );

    test(
      'FP: nested Builder using its own inner context is not reported',
      () async {
        final errors = await _runRule('''
void open(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => Builder(
      builder: (innerContext) =>
          Text('\${Theme.of(innerContext).textTheme.titleMedium}'),
    ),
  );
}
''');
        expect(_codes(errors), isEmpty);
      },
    );

    test(
      'FP: controller declared inside the builder closure is not reported',
      () async {
        final errors = await _runRule('''
void open(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) {
      final TextEditingController local = TextEditingController();
      return TextField(controller: local);
    },
  );
}
''');
        expect(_codes(errors), isEmpty);
      },
    );
  });
}

List<String> _codes(List<Diagnostic> errors) =>
    errors.map((Diagnostic e) => e.diagnosticCode.lowerCaseName).toList();

Future<List<Diagnostic>> _runRule(String source) => runRule(
  OverlayLifecycleContextSafetyLint(),
  '$_fixturePrelude\n$source',
  path: 'lib/presentation/screens/test_overlay.dart',
  packageName: 'lint_test_project',
  mustResolve: false,
);

const String _fixturePrelude = r'''
class Key {}

class BuildContext {}

extension BuildContextLookups on BuildContext {
  T read<T>() => throw UnimplementedError();
  T watch<T>() => throw UnimplementedError();
}

class Widget {
  const Widget({Key? key});
}

class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
  Widget build(BuildContext context) => const Widget();
}

class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
}

abstract class State<T extends StatefulWidget> {
  void dispose() {}
}

class Text extends Widget {
  const Text(String data, {Object? style});
}

class AlertDialog extends Widget {
  const AlertDialog({Object? content});
}

class TextField extends Widget {
  const TextField({Object? controller, bool autofocus = false});
}

class Builder extends Widget {
  const Builder({required this.builder, Key? key}) : super(key: key);
  final Widget Function(BuildContext context) builder;
}

class TextEditingController {
  void dispose() {}
}

class AppLocalizations {
  static AppLocalizations? of(BuildContext context) => null;
  String get title => 'title';
}

class MediaQuery extends Widget {
  const MediaQuery({Object? data, Object? child});
  static MediaQueryData of(BuildContext context) => MediaQueryData();
}

class MediaQueryData {}

class MaterialPageRoute<T> {
  MaterialPageRoute({required this.builder});
  final Widget Function(BuildContext context) builder;
}

class TimeOfDay {}

Future<TimeOfDay?> showTimePicker({
  required BuildContext context,
  required Widget Function(BuildContext context, Widget? child) builder,
}) async => null;

class Theme {
  static ThemeData of(BuildContext context) => ThemeData();
}

class ThemeData {
  TextTheme get textTheme => TextTheme();
}

class TextTheme {
  Object? get titleMedium => null;
  Object? get bodyMedium => null;
}

Future<T?> showDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
}) async => null;

Future<T?> showModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
}) async => null;
''';

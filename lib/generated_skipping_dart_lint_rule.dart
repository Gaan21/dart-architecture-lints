import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:analyzer/error/listener.dart';

abstract class GeneratedSkippingDartLintRule extends DartLintRule {
  const GeneratedSkippingDartLintRule({required super.code});

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final uri = resolver.source.uri;
    if (_looksGenerated(uri)) return; // ignora el archivo completo
    runOnNonGenerated(resolver, reporter, context);
  }

  // Tus reglas implementan esto en lugar de run(...)
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  );
}

bool _looksGenerated(Uri uri) {
  final p = uri.path;
  // Sufijos y rutas típicas de código generado
  const suffixes = [
    '.g.dart',
    '.freezed.dart',
    '.mocks.dart',
    '.gr.dart',
    '.gen.dart',
    '.pb.dart',
    '.pbenum.dart',
    '.pbjson.dart',
    '.pbgrpc.dart',
    '.swagger.dart',
    '.chopper.dart',
  ];
  if (p.contains('/generated/') ||
      p.contains('/.dart_tool/') ||
      p.contains('/build/')) {
    return true;
  }
  return suffixes.any(p.endsWith);
}

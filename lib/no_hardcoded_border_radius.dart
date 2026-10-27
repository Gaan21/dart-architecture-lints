import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:dart_architecture_lints/timezone_safety_utils.dart';

class NoHardcodedBorderRadiusLint extends GeneratedSkippingDartLintRule {
  NoHardcodedBorderRadiusLint({
    this.config = const NoHardcodedBorderRadiusConfig(),
  }) : super(code: _codeSm);

  final NoHardcodedBorderRadiusConfig config;

  static const _codeSm = LintCode(
    'no_hardcoded_border_radius',
    'Usa AppSpacing.radiusSm en lugar de BorderRadius.circular(6)',
    correctionMessage: 'Reemplaza el literal por AppSpacing.radiusSm.',
  );

  static const _codeMd = LintCode(
    'no_hardcoded_border_radius',
    'Usa AppSpacing.radiusMd en lugar de BorderRadius.circular(12)',
    correctionMessage: 'Reemplaza el literal por AppSpacing.radiusMd.',
  );

  static const _codeLg = LintCode(
    'no_hardcoded_border_radius',
    'Usa AppSpacing.radiusLg en lugar de BorderRadius.circular(16)',
    correctionMessage: 'Reemplaza el literal por AppSpacing.radiusLg.',
  );

  static const _tokenByValue = {6: _codeSm, 12: _codeMd, 16: _codeLg};

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final path = normalizeLintPath(resolver.path);
    if (!config.matchesPath(path)) return;

    // BorderRadius.circular is a named constructor → InstanceCreationExpression
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final constructorName = node.constructorName;
      if (constructorName.type.name.lexeme != 'BorderRadius') return;
      if (constructorName.name?.name != 'circular') return;

      final args = node.argumentList.arguments;
      if (args.length != 1) return;

      final arg = args.first;
      final expr = arg is NamedArgument ? arg.argumentExpression : arg;

      if (expr is! IntegerLiteral) return;
      final value = expr.value;
      if (value == null) return;

      final code = _tokenByValue[value];
      if (code == null) return;

      reporter.atNode(node, code);
    });
  }
}

class NoHardcodedBorderRadiusConfig {
  const NoHardcodedBorderRadiusConfig({
    this.includeGlobs = _defaultIncludes,
    this.excludeGlobs = _defaultExcludes,
  });

  static const _defaultIncludes = ['**/presentation/**'];

  static const _defaultExcludes = [
    '**/theme/**',
    '**/*_painter.dart',
    '**/test/**',
    '**/tests/**',
    '**/*_test.dart',
  ];

  final List<String> includeGlobs;
  final List<String> excludeGlobs;

  bool matchesPath(String normalizedPath) {
    if (!matchesAnyGlob(normalizedPath, includeGlobs)) return false;
    if (excludeGlobs.isNotEmpty &&
        matchesAnyGlob(normalizedPath, excludeGlobs)) {
      return false;
    }
    return true;
  }
}

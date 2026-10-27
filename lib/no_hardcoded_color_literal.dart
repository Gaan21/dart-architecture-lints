import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:dart_architecture_lints/timezone_safety_utils.dart';

class NoHardcodedColorLiteralLint extends GeneratedSkippingDartLintRule {
  NoHardcodedColorLiteralLint({
    this.config = const NoHardcodedColorLiteralConfig(),
  }) : super(code: _code);

  final NoHardcodedColorLiteralConfig config;

  static const _code = LintCode(
    'no_hardcoded_color_literal',
    'Evita Color(0x...) directo en presentación — usa un token de AppColors o Theme.of(context).colorScheme.*',
    correctionMessage: 'Reemplaza el literal hexadecimal por una constante de AppColors o un valor de colorScheme.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final path = normalizeLintPath(resolver.path);
    if (!config.matchesPath(path)) return;

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      // Only the default Color(int) constructor — not Color.fromARGB, etc.
      final constructorName = node.constructorName;
      if (constructorName.type.name.lexeme != 'Color') return;
      if (constructorName.name != null) return; // named constructor → skip

      final args = node.argumentList.arguments;
      if (args.length != 1) return;

      final arg = args.first;
      // Strip any named-argument wrapper (shouldn't happen for Color, but safe)
      final expr = arg is NamedArgument ? arg.argumentExpression : arg;

      if (expr is! IntegerLiteral) return;

      // Only hex literals: source starts with 0x or 0X
      final src = expr.literal.lexeme;
      if (!src.startsWith('0x') && !src.startsWith('0X')) return;

      reporter.atNode(node, _code);
    });
  }
}

class NoHardcodedColorLiteralConfig {
  const NoHardcodedColorLiteralConfig({
    this.includeGlobs = _defaultIncludes,
    this.excludeGlobs = _defaultExcludes,
  });

  static const _defaultIncludes = ['**/presentation/**'];

  static const _defaultExcludes = [
    '**/*_painter.dart',
    '**/theme/**',
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

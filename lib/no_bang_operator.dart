import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that discourages the use of the null assertion operator (!).
/// Suggests using null-aware operators like ?? for safer null handling.
class NoBangOperatorLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoBangOperatorLint].
  const NoBangOperatorLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Usa operadores null-aware (??, ?., ?..[]) o checks explícitos (if != null) en lugar del operador !.\n'
        'Ejemplos:\n'
        '  // ❌ value!\n'
        '  // ✅ value ?? defaultValue\n'
        '  // ✅ value?.property\n'
        '  // ✅ if (value != null) { value.use() }',
    name: 'no_bang_operator',
    problemMessage:
        'El operador ! puede causar crashes en runtime si el valor es null. Debe reemplazarse con patrones más seguros de manejo de nulos.',
  );

  /// Executes the lint rule to detect instances of the null assertion operator.
  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPostfixExpression((PostfixExpression node) {
      if (node.operator.type == TokenType.BANG) {
        reporter.atNode(
          node,
          _code,
        );
      }
    });
  }
}

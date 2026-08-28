import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces the use of 'final' over 'var' for immutable variables.
/// Follows the guideline: "No usar 'var' (salvo casos locales inmutables muy evidentes)"
class EnforceFinalVariablesLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [EnforceFinalVariablesLint].
  const EnforceFinalVariablesLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    name: 'enforce_final_variables',
    problemMessage:
        'Variable declarada con "var" debería usar "final" para valores inmutables. Esto previene mutaciones accidentales y mejora la legibilidad del código.',
    correctionMessage:
        'Usa "final" en lugar de "var" para variables que no se reasignan.\n'
        'Excepciones válidas: for loops, variables temporales que SÍ se reasignan múltiples veces.\n'
        'Ejemplo:\n'
        '  // ❌ var name = "John";\n'
        '  // ✅ final name = "John";',
  );

  /// Executes the lint rule to detect inappropriate uses of 'var'.
  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclarationList((VariableDeclarationList node) {
      // Only check 'var' declarations
      if (node.keyword?.type == Keyword.VAR) {
        // Check if this is an acceptable context for 'var'
        if (!_isAcceptableVarContext(node)) {
          reporter.atToken(
            node.keyword!,
            _code,
          );
        }
      }
    });
  }

  /// Determines if 'var' usage is acceptable in this context.
  ///
  /// Acceptable contexts include:
  /// - For loop variables (for (var i = 0; ...))
  /// - Variables that are clearly reassigned in local scope
  bool _isAcceptableVarContext(VariableDeclarationList node) {
    // Check if we're in a for loop
    final forStatement = node.thisOrAncestorOfType<ForStatement>();
    if (forStatement != null) {
      // Check if this variable declaration is the loop variable
      if (forStatement.forLoopParts is ForPartsWithDeclarations) {
        final forParts = forStatement.forLoopParts as ForPartsWithDeclarations;
        if (forParts.variables == node) {
          return true; // Allow var in for loop declarations
        }
      }
    }

    // Check if we're in an enhanced for loop (for-in)
    final forEachStatement =
        node.thisOrAncestorOfType<ForEachPartsWithDeclaration>();
    if (forEachStatement != null &&
        forEachStatement.loopVariable.parent == node) {
      return true; // Allow var in for-in loops
    }

    // Check if variable is clearly being reassigned locally
    // This would require more complex analysis to detect reassignment patterns
    // For now, we'll be strict and suggest final unless in loops

    return false;
  }
}

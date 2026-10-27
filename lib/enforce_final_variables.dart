import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces the use of 'final' over 'var' for immutable variables.
class EnforceFinalVariablesLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [EnforceFinalVariablesLint].
  EnforceFinalVariablesLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'enforce_final_variables',
    'This local variable is never reassigned.',
    correctionMessage:
        'Use final for a local binding that is never reassigned.',
  );

  /// Executes the lint rule to detect inappropriate uses of 'var'.
  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addVariableDeclarationList((VariableDeclarationList node) {
      // Only check 'var' declarations
      if (node.keyword?.type == Keyword.VAR) {
        // Fields and top-level bindings may be written from other libraries.
        if (node.parent is! VariableDeclarationStatement) return;
        // Check if this is an acceptable context for 'var'
        if (!_isAcceptableVarContext(node)) {
          reporter.atToken(node.keyword!, _code);
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
    final forEachStatement = node
        .thisOrAncestorOfType<ForEachPartsWithDeclaration>();
    if (forEachStatement != null &&
        forEachStatement.loopVariable.parent == node) {
      return true; // Allow var in for-in loops
    }

    final scope = node.thisOrAncestorOfType<FunctionBody>();
    if (scope == null) return true;
    return node.variables.every((variable) {
      final visitor = _Writes(variable.declaredFragment?.element);
      scope.accept(visitor);
      return visitor.found;
    });
  }
}

class _Writes extends RecursiveAstVisitor<void> {
  _Writes(this.element);
  final Object? element;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (element != null && node.element == element && node.inSetterContext()) {
      found = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

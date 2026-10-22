import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Reports `throw` and `rethrow` in methods of classes whose name contains
/// `UseCase` or `Repository`, including private helpers, unless the exception
/// is provably caught by a local `try` in the same function body.
///
/// Escaping throws break the Result contract; return a Failure instead. This
/// lexical check does not prove that called code cannot throw.
class NoResultThrowLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoResultThrowLint].
  const NoResultThrowLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    name: 'no_result_throw',
    problemMessage:
        'Do not throw exceptions in UseCase or Repository. Return Failure(AppException(...)) instead to maintain Result<T> contract.',
    correctionMessage:
        'Replace throw with: return Failure(AppException.validation(code: "...", message: "..."));',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final className = node.name.lexeme;

      // Only check UseCase and Repository classes
      if (!_isUseCaseOrRepository(className)) return;

      // Find all throw statements in the class
      for (final member in node.members) {
        if (member is MethodDeclaration) {
          _checkMethodForThrows(member, reporter);
        }
      }
    });
  }

  /// Checks if class name suggests it's a UseCase or Repository.
  bool _isUseCaseOrRepository(String className) {
    return className.contains('UseCase') || className.contains('Repository');
  }

  /// Recursively checks method body for throw statements.
  void _checkMethodForThrows(
    MethodDeclaration method,
    DiagnosticReporter reporter,
  ) {
    method.body.visitChildren(_ThrowStatementVisitor(reporter, _code));
  }
}

/// Visitor reporting `throw`/`rethrow` that can leave the enclosing function.
///
/// A throw is exempt only when it is lexically inside the `try` block of a
/// try statement in the same function body whose catch clause catches it: a
/// clause without `on`, `on Object`, or an `on` type that is a supertype of the
/// thrown static type (for `rethrow`, the type caught by its own clause).
/// Closures are a boundary because they may run outside the `try`.
class _ThrowStatementVisitor extends RecursiveAstVisitor<void> {
  final DiagnosticReporter reporter;
  final LintCode code;

  _ThrowStatementVisitor(this.reporter, this.code);

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (!_caughtLocally(node, node.expression.staticType)) {
      reporter.atNode(node, code);
    }
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    final clause = node.thisOrAncestorOfType<CatchClause>();
    if (!_caughtLocally(node, clause?.exceptionType?.type)) {
      reporter.atNode(node, code);
    }
    super.visitRethrowExpression(node);
  }

  bool _caughtLocally(AstNode node, DartType? thrown) {
    final typeSystem =
        (node.root as CompilationUnit).declaredFragment?.element.typeSystem;
    AstNode child = node;
    for (
      var parent = node.parent;
      parent != null && parent is! FunctionBody;
      parent = parent.parent
    ) {
      if (parent is TryStatement && identical(parent.body, child)) {
        for (final clause in parent.catchClauses) {
          final caught = clause.exceptionType?.type;
          if (caught == null || caught.isDartCoreObject) return true;
          if (thrown != null &&
              thrown is! DynamicType &&
              thrown is! InvalidType &&
              typeSystem != null &&
              typeSystem.isSubtypeOf(thrown, caught)) {
            return true;
          }
        }
      }
      child = parent;
    }
    return false;
  }
}

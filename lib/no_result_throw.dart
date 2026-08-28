import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prohibits ALL throw statements in UseCases and Repositories.
///
/// These classes must return Result<T> for all errors, not throw exceptions.
/// Both `throw new Exception()` and `rethrow` break the Result<T> contract.
/// The correct pattern is to always return Failure(AppException(...)).
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
  void _checkMethodForThrows(MethodDeclaration method, DiagnosticReporter reporter) {
    method.body.visitChildren(_ThrowStatementVisitor(reporter, _code));
  }
}

/// Visitor to find ALL throw statements (including rethrow).
///
/// In UseCase/Repository methods that return Result<T>, ALL throws break
/// the contract - both new exceptions and rethrow. The correct pattern is
/// to always return Failure(AppException(...)) instead.
class _ThrowStatementVisitor extends RecursiveAstVisitor<void> {
  final DiagnosticReporter reporter;
  final LintCode code;

  _ThrowStatementVisitor(this.reporter, this.code);

  @override
  void visitThrowExpression(ThrowExpression node) {
    // Prohibit "throw Exception()" - breaks Result<T> contract
    reporter.atNode(node, code);
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    // Prohibit "rethrow" - also breaks Result<T> contract
    reporter.atNode(node, code);
    super.visitRethrowExpression(node);
  }
}

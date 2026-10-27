import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Enforces centralized 401 handling in authentication boundary classes only.
class AvoidScattered401HandlingLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [AvoidScattered401HandlingLint].
  AvoidScattered401HandlingLint() : super(code: _code);

  static const _allowedClasses = {'AuthInterceptor', 'AuthService'};

  static const _code = LintCode(
    'avoid_scattered_401_handling',
    '401 handling must be centralized in AuthInterceptor/AuthService. Avoid scattered authentication logic.',
    correctionMessage: 'Move unauthorized handling to AuthInterceptor/AuthService and keep callers free of auth-recovery branches.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    if (_isTestFile(resolver.path)) return;

    final reportedOffsets = HashSet<int>();

    context.registry.addIfStatement((IfStatement node) {
      final condition = node.expression;
      if (condition is BinaryExpression && _is401Comparison(condition)) {
        if (_isInsideAllowedClass(condition)) return;
        if (reportedOffsets.add(condition.offset)) {
          reporter.atNode(condition, _code);
        }
      }
    });

    context.registry.addBinaryExpression((BinaryExpression node) {
      if (!_is401Comparison(node)) return;
      if (_isInsideAllowedClass(node)) return;
      if (reportedOffsets.add(node.offset)) {
        reporter.atNode(node, _code);
      }
    });
  }

  bool _isTestFile(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/test/');
  }

  bool _isInsideAllowedClass(AstNode node) {
    final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return false;
    return _allowedClasses.contains(classNode.namePart.typeName.lexeme);
  }

  bool _is401Comparison(BinaryExpression node) {
    if (node.operator.type.lexeme != '==') return false;

    final left = node.leftOperand;
    final right = node.rightOperand;

    return (_isStatusCodeExpression(left) && _isInt401(right)) ||
        (_isStatusCodeExpression(right) && _isInt401(left));
  }

  bool _isInt401(Expression expression) {
    final unwrapped = expression.unParenthesized;
    return unwrapped is IntegerLiteral && unwrapped.value == 401;
  }

  bool _isStatusCodeExpression(Expression expression) {
    final unwrapped = expression.unParenthesized;

    if (unwrapped is SimpleIdentifier) {
      return unwrapped.name == 'statusCode';
    }

    if (unwrapped is PropertyAccess) {
      return unwrapped.propertyName.name == 'statusCode';
    }

    if (unwrapped is PrefixedIdentifier) {
      return unwrapped.identifier.name == 'statusCode';
    }

    return false;
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Ensures UiState classes invoke super.dispose(), avoiding leaked listeners.
class UiStateMustCallSuperDisposeLint extends GeneratedSkippingDartLintRule {
  /// Creates a new instance of the lint.
  UiStateMustCallSuperDisposeLint() : super(code: _code);

  static const _code = LintCode(
    'uistate_must_call_super_dispose',
    'UiState dispose() is missing super.dispose(). This can leak listeners and timers managed by the base ChangeNotifier.',
    correctionMessage: 'Call super.dispose() at the end of dispose() to ensure the ChangeNotifier cleans up listeners and resources.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'dispose') return;
      if (isAbstractMethod(node)) return;

      final uiStateClass = _enclosingUiState(node);
      if (uiStateClass == null) return;

      if (!_callsSuperDispose(node)) {
        reporter.atNode(node, _code);
      }
    });
  }

  ClassDeclaration? _enclosingUiState(MethodDeclaration method) {
    final classDeclaration = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classDeclaration == null) return null;

    if (!_looksLikeUiState(classDeclaration)) return null;

    return classDeclaration;
  }

  bool _looksLikeUiState(ClassDeclaration classDeclaration) {
    if (_hasUiStateName(classDeclaration.namePart.typeName.lexeme)) return true;

    final extendsClause = classDeclaration.extendsClause;
    if (extendsClause != null) {
      final extendsName = _typeName(extendsClause.superclass);
      if (extendsName != null && _hasUiStateName(extendsName)) {
        return true;
      }
    }

    final withClause = classDeclaration.withClause;
    if (withClause != null) {
      for (final mixinType in withClause.mixinTypes) {
        final mixinName = _typeName(mixinType);
        if (mixinName != null && _hasUiStateName(mixinName)) {
          return true;
        }
      }
    }

    final implementsClause = classDeclaration.implementsClause;
    if (implementsClause != null) {
      for (final interfaceType in implementsClause.interfaces) {
        final interfaceName = _typeName(interfaceType);
        if (interfaceName != null && _hasUiStateName(interfaceName)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _hasUiStateName(String name) =>
      name.endsWith('UiState') || name == 'UiState';

  String? _typeName(TypeAnnotation annotation) {
    if (annotation is NamedType) {
      final resolved = annotation.type;
      if (resolved != null) {
        return resolved.getDisplayString();
      }
      return annotation.name.lexeme;
    }
    return null;
  }

  bool _callsSuperDispose(MethodDeclaration method) {
    final body = method.body;
    if (body is! BlockFunctionBody) return false;

    return _containsSuperDispose(body.block);
  }

  bool _containsSuperDispose(Block block) {
    for (final statement in block.statements) {
      if (_statementContainsSuperDispose(statement)) {
        return true;
      }
    }
    return false;
  }

  bool _statementContainsSuperDispose(Statement statement) {
    if (statement is ExpressionStatement) {
      return _expressionIsSuperDispose(statement.expression);
    }

    if (statement is Block) {
      return _containsSuperDispose(statement);
    }

    if (statement is IfStatement) {
      if (_statementContainsSuperDispose(statement.thenStatement)) {
        return true;
      }
      final elseStatement = statement.elseStatement;
      if (elseStatement != null &&
          _statementContainsSuperDispose(elseStatement)) {
        return true;
      }
    }

    if (statement is TryStatement) {
      if (_containsSuperDispose(statement.body)) return true;
      for (final clause in statement.catchClauses) {
        if (_containsSuperDispose(clause.body)) return true;
      }
      final finallyBlock = statement.finallyBlock;
      if (finallyBlock != null && _containsSuperDispose(finallyBlock)) {
        return true;
      }
    }

    return false;
  }

  bool _expressionIsSuperDispose(Expression expression) {
    if (expression is! MethodInvocation) return false;
    final target = expression.target;
    if (target is! SuperExpression) return false;
    return expression.methodName.name == 'dispose';
  }
}

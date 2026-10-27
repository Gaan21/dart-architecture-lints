import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that ensures ViewModels call super.dispose() in their dispose method.
/// Proper disposal is critical for preventing memory leaks and ensuring cleanup.
class ViewModelsCallSuperDisposeLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [ViewModelsCallSuperDisposeLint].
  ViewModelsCallSuperDisposeLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'viewmodels_call_super_dispose',
    'ViewModel dispose() methods must call super.dispose() for proper cleanup and preventing memory leaks.',
    correctionMessage: 'Add super.dispose() at the end of the dispose method',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only check dispose methods
      if (node.name.lexeme != 'dispose') return;

      // Skip abstract methods
      if (isAbstractMethod(node)) return;

      // Check if this class extends a ViewModel base class
      if (!_isInViewModelClass(node)) return;

      // Check if dispose method calls super.dispose()
      if (!_callsSuperDispose(node)) {
        reporter.atNode(node, _code);
      }
    });
  }

  /// Checks if the method is in a class that extends a ViewModel base class.
  bool _isInViewModelClass(MethodDeclaration method) {
    final classDeclaration = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classDeclaration == null) return false;

    // Exclude UiState classes (handled by uistate_must_call_super_dispose rule)
    final className = classDeclaration.namePart.typeName.lexeme;
    if (_isUiStateClass(className, classDeclaration)) return false;

    final extendsClause = classDeclaration.extendsClause;
    if (extendsClause == null) return false;

    final supertype = extendsClause.superclass;
    final supertypeName = supertype.name.lexeme;

    // Common ViewModel base classes
    final viewModelTypes = {
      'ViewModel',
      'BaseViewModel',
      'ChangeNotifier',
      'ValueNotifier',
      'Cubit',
      'Bloc',
    };

    if (viewModelTypes.contains(supertypeName)) return true;

    // Check if it extends a class that might be a ViewModel
    return _hasViewModelInName(supertypeName) || _extendsViewModel(supertype);
  }

  /// Checks if class is a UiState (should be handled by different rule).
  bool _isUiStateClass(String className, ClassDeclaration classDeclaration) {
    // Check class name ends with UiState
    if (className.endsWith('UiState') || className == 'UiState') return true;

    // Check if extends a class with UiState in name
    final extendsClause = classDeclaration.extendsClause;
    if (extendsClause != null) {
      final supertypeName = extendsClause.superclass.name.lexeme;
      if (supertypeName.endsWith('UiState') || supertypeName == 'UiState') {
        return true;
      }
    }

    // Check mixins
    final withClause = classDeclaration.withClause;
    if (withClause != null) {
      for (final mixinType in withClause.mixinTypes) {
        final mixinName = mixinType.name.lexeme;
        if (mixinName.endsWith('UiState') || mixinName == 'UiState') {
          return true;
        }
      }
    }

    return false;
  }

  /// Checks if class name suggests it's a ViewModel.
  bool _hasViewModelInName(String className) {
    return className.contains('ViewModel') ||
        className.contains('Model') ||
        className.contains('Controller') ||
        className.contains('Provider');
  }

  /// Recursively checks if a type extends a ViewModel class.
  bool _extendsViewModel(NamedType type) {
    final element = type.type?.element;
    if (element is! ClassElement) return false;

    final supertype = element.supertype;
    if (supertype == null) return false;

    final String supertypeName = supertype.element.name ?? '';

    // Check common Flutter/Dart classes that need super.dispose()
    final knownTypes = {'ChangeNotifier', 'ValueNotifier', 'Cubit', 'Bloc'};

    if (knownTypes.contains(supertypeName)) return true;

    // Avoid infinite recursion
    if (supertypeName == 'Object') return false;

    return _hasViewModelInName(supertypeName);
  }

  /// Checks if the dispose method contains a call to super.dispose().
  bool _callsSuperDispose(MethodDeclaration method) {
    final body = method.body;
    if (body is! BlockFunctionBody) return false;

    final block = body.block;
    return _containsSuperDisposeCall(block);
  }

  /// Recursively searches for super.dispose() calls in a block of statements.
  bool _containsSuperDisposeCall(Block block) {
    for (final statement in block.statements) {
      if (_statementContainsSuperDispose(statement)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if a statement contains a super.dispose() call.
  bool _statementContainsSuperDispose(Statement statement) {
    // Direct expression statement with super.dispose()
    if (statement is ExpressionStatement) {
      return _expressionIsSuperDispose(statement.expression);
    }

    // Check inside if statements, try-catch, etc.
    if (statement is IfStatement) {
      return _statementContainsSuperDispose(statement.thenStatement) ||
          (statement.elseStatement != null &&
              _statementContainsSuperDispose(statement.elseStatement!));
    }

    if (statement is TryStatement) {
      return _containsSuperDisposeCall(statement.body) ||
          statement.catchClauses.any(
            (clause) => _containsSuperDisposeCall(clause.body),
          ) ||
          (statement.finallyBlock != null &&
              _containsSuperDisposeCall(statement.finallyBlock!));
    }

    if (statement is Block) {
      return _containsSuperDisposeCall(statement);
    }

    return false;
  }

  /// Checks if an expression is a super.dispose() method invocation.
  bool _expressionIsSuperDispose(Expression expression) {
    if (expression is! MethodInvocation) return false;

    final target = expression.target;
    if (target is! SuperExpression) return false;

    return expression.methodName.name == 'dispose';
  }
}

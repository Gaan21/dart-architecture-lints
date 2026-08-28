import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that ensures StreamController fields are closed in dispose() method.
/// Prevents memory leaks by enforcing proper cleanup of StreamControllers.
class StreamControllerMustClose extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [StreamControllerMustClose].
  const StreamControllerMustClose() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Añade _streamController.close() en el método dispose() antes de llamar super.dispose().\n'
        'Si el StreamController es inyectado externamente, añade comentario: // ignore: streamcontroller_must_close\n'
        'Ejemplo:\n'
        '  class MyViewModel extends BaseViewModelWithEffects<User> {\n'
        '    final _effects = StreamController<UiEffect>.broadcast();\n'
        '    Stream<UiEffect> get uiEffects => _effects.stream;\n'
        '    \n'
        '    @override\n'
        '    void dispose() {\n'
        '      _effects.close(); // ← Cierra antes de super.dispose()\n'
        '      super.dispose();\n'
        '    }\n'
        '  }',
    name: 'streamcontroller_must_close',
    problemMessage:
        'StreamController debe cerrarse en dispose() para evitar memory leaks.',
  );

  /// Executes the lint rule to detect StreamController fields without .close() in dispose.
  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Solo verificar clases que:
      // 1. Están en lib/presentation/viewModels/
      // 2. O extienden ChangeNotifier, BaseViewModel, BaseViewModelWithEffects
      if (!_shouldCheckClass(node, resolver)) {
        return;
      }

      // Recopilar todos los StreamController fields
      final streamControllerFields = <FieldDeclaration>[];
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          if (_isStreamControllerField(member)) {
            streamControllerFields.add(member);
          }
        }
      }

      // Si no hay StreamControllers, no hay nada que verificar
      if (streamControllerFields.isEmpty) {
        return;
      }

      // Buscar método dispose()
      MethodDeclaration? disposeMethod;
      for (final member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      // Si no hay dispose(), reportar todos los StreamControllers
      if (disposeMethod == null) {
        for (final field in streamControllerFields) {
          reporter.atNode(field, _code);
        }
        return;
      }

      // Verificar que cada StreamController se cierre en dispose()
      for (final field in streamControllerFields) {
        final fieldNames = _getFieldNames(field);
        var isClosed = false;

        for (final fieldName in fieldNames) {
          if (_disposeCallsClose(disposeMethod, fieldName)) {
            isClosed = true;
            break;
          }
        }

        if (!isClosed) {
          reporter.atNode(field, _code);
        }
      }
    });
  }

  /// Determines if a class should be checked for StreamController cleanup.
  bool _shouldCheckClass(ClassDeclaration node, CustomLintResolver resolver) {
    final uri = resolver.source.uri;
    final path = uri.path;

    // 1. Verificar si está en presentation/viewModels/
    if (path.contains('/presentation/viewModels/')) {
      return true;
    }

    // 2. Verificar si extiende ChangeNotifier, BaseViewModel, o BaseViewModelWithEffects
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name.lexeme;
      final viewModelBaseClasses = {
        'ChangeNotifier',
        'BaseViewModel',
        'BaseViewModelWithEffects',
      };

      if (viewModelBaseClasses.contains(superclassName)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if a field is a StreamController.
  bool _isStreamControllerField(FieldDeclaration field) {
    final type = field.fields.type;
    if (type is NamedType) {
      final typeName = type.name.lexeme;
      return typeName == 'StreamController';
    }
    return false;
  }

  /// Extracts field names from a field declaration.
  List<String> _getFieldNames(FieldDeclaration field) {
    return field.fields.variables.map((v) => v.name.lexeme).toList();
  }

  /// Checks if dispose() method calls .close() on the given field name.
  bool _disposeCallsClose(MethodDeclaration disposeMethod, String fieldName) {
    final body = disposeMethod.body;
    if (body is! BlockFunctionBody) {
      return false;
    }

    return _blockContainsClose(body.block, fieldName);
  }

  /// Recursively searches for fieldName.close() calls in a block of statements.
  bool _blockContainsClose(Block block, String fieldName) {
    for (final statement in block.statements) {
      if (_statementContainsClose(statement, fieldName)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if a statement contains fieldName.close() call.
  bool _statementContainsClose(Statement statement, String fieldName) {
    // Direct expression statement with fieldName.close()
    if (statement is ExpressionStatement) {
      return _expressionIsClose(statement.expression, fieldName);
    }

    // Check inside if statements
    if (statement is IfStatement) {
      return _statementContainsClose(statement.thenStatement, fieldName) ||
          (statement.elseStatement != null &&
              _statementContainsClose(statement.elseStatement!, fieldName));
    }

    // Check inside try-catch-finally
    if (statement is TryStatement) {
      return _blockContainsClose(statement.body, fieldName) ||
          statement.catchClauses.any(
            (clause) => _blockContainsClose(clause.body, fieldName),
          ) ||
          (statement.finallyBlock != null &&
              _blockContainsClose(statement.finallyBlock!, fieldName));
    }

    // Check nested blocks
    if (statement is Block) {
      return _blockContainsClose(statement, fieldName);
    }

    return false;
  }

  /// Checks if an expression is fieldName.close() or await fieldName.close().
  bool _expressionIsClose(Expression expression, String fieldName) {
    // Handle await expression
    if (expression is AwaitExpression) {
      return _expressionIsClose(expression.expression, fieldName);
    }

    // Handle method invocation
    if (expression is MethodInvocation) {
      // Check if method name is "close"
      if (expression.methodName.name != 'close') {
        return false;
      }

      // Check target
      final target = expression.target;

      // Direct field access: _controller.close()
      if (target is SimpleIdentifier && target.name == fieldName) {
        return true;
      }

      // Nullable field access: _controller?.close()
      if (target is SimpleIdentifier && target.name == fieldName) {
        return true;
      }

      // Property access with null-aware: _controller?.close()
      if (target is PropertyAccess) {
        final propertyTarget = target.target;
        if (propertyTarget is SimpleIdentifier &&
            propertyTarget.name == fieldName) {
          return true;
        }
      }
    }

    return false;
  }
}

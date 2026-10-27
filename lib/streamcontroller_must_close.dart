import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';

import 'generated_skipping_dart_lint_rule.dart';
import 'resource_types.dart';

/// Checks locally owned controllers without taking ownership of injected ones.
class StreamControllerMustClose extends GeneratedSkippingDartLintRule {
  StreamControllerMustClose() : super(code: _code);

  static const _code = LintCode(
    'streamcontroller_must_close',
    'An owned StreamController is not closed on every normal dispose exit.',
    correctionMessage:
        'Close this owned controller in dispose or a local cleanup helper. '
        'Do not close borrowed controllers; ownership must remain with their creator.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      final element = node.declaredFragment?.element;
      final bases =
          element?.allSupertypes.map((type) => type.element.name) ?? [];
      if (!resolver.path.contains('/presentation/viewModels/') &&
          !bases.any(
            const {
              'ChangeNotifier',
              'BaseViewModel',
              'BaseViewModelWithEffects',
            }.contains,
          )) {
        return;
      }
      final methods = node.body.members.whereType<MethodDeclaration>().toList();
      final dispose = methods
          .where((method) => method.name.lexeme == 'dispose')
          .firstOrNull;
      for (final field in node.body.members.whereType<FieldDeclaration>()) {
        if (field.isStatic) continue;
        for (final variable in field.fields.variables) {
          final fieldElement = variable.declaredFragment?.element;
          if (!isResourceType(fieldElement?.type, const {
            'StreamController',
          }, libraryUri: 'dart:async')) {
            continue;
          }
          // No initializer means borrowed/unknown ownership, unless a constructor
          // initializer explicitly creates the resource.
          final initializers = <Expression>[
            if (variable.initializer != null) variable.initializer!,
            for (final constructor
                in node.body.members.whereType<ConstructorDeclaration>())
              for (final initializer
                  in constructor.initializers
                      .whereType<ConstructorFieldInitializer>())
                if (initializer.fieldName.element == fieldElement)
                  initializer.expression,
          ];
          if (!initializers
              .map(_unwrapReference)
              .any(
                (expression) =>
                    expression is! Identifier && expression is! PropertyAccess,
              )) {
            continue;
          }
          final flow = _CleanupFlow(fieldElement!, methods);
          final paths = dispose == null
              ? const [_Path(false)]
              : flow.body(dispose.body, const [_Path(false)], {});
          if (paths.any((path) => path.exit != _Exit.thrown && !path.closed)) {
            reporter.atNode(variable, _code);
          }
        }
      }
    });
  }
}

/// These wrappers preserve resource identity; they do not transfer ownership.
Expression _unwrapReference(Expression expression) {
  while (true) {
    if (expression is ParenthesizedExpression) {
      expression = expression.expression;
    } else if (expression is AsExpression) {
      expression = expression.expression;
    } else if (expression is PostfixExpression &&
        expression.operator.lexeme == '!') {
      expression = expression.operand;
    } else {
      return expression;
    }
  }
}

enum _Exit { active, returned, thrown }

class _Path {
  const _Path(this.closed, [this.exit = _Exit.active]);
  final bool closed;
  final _Exit exit;
}

class _CleanupFlow {
  _CleanupFlow(this.field, this.methods);
  final Element field;
  final List<MethodDeclaration> methods;

  List<_Path> body(
    FunctionBody body,
    List<_Path> paths,
    Set<Element> visiting,
  ) {
    if (body is BlockFunctionBody) {
      return statement(body.block, paths, visiting);
    }
    if (body is ExpressionFunctionBody) {
      return expression(body.expression, paths, visiting);
    }
    return paths;
  }

  List<_Path> statement(
    Statement node,
    List<_Path> paths,
    Set<Element> visiting,
  ) {
    final done = paths.where((path) => path.exit != _Exit.active).toList();
    final active = paths.where((path) => path.exit == _Exit.active).toList();
    if (active.isEmpty) return paths;
    List<_Path> result;
    if (node is Block) {
      result = active;
      for (final child in node.statements) {
        result = statement(child, result, visiting);
      }
    } else if (node is ExpressionStatement) {
      result = expression(node.expression, active, visiting);
    } else if (node is ReturnStatement) {
      result = node.expression == null
          ? active
          : expression(node.expression!, active, visiting);
      result = result
          .map((path) => _Path(path.closed, _Exit.returned))
          .toList();
    } else if (node is IfStatement) {
      result = [
        ...statement(node.thenStatement, active, visiting),
        ...node.elseStatement == null
            ? active
            : statement(node.elseStatement!, active, visiting),
      ];
    } else if (node is TryStatement) {
      result = statement(node.body, active, visiting);
      // A catch can be entered before any successful cleanup in the try body.
      for (final clause in node.catchClauses) {
        result.addAll(statement(clause.body, active, visiting));
      }
      if (node.finallyBlock != null) {
        result = [
          for (final path in result)
            for (final finalPath in statement(node.finallyBlock!, [
              _Path(path.closed),
            ], visiting))
              _Path(
                finalPath.closed,
                finalPath.exit == _Exit.active ? path.exit : finalPath.exit,
              ),
        ];
      }
    } else if (node is ForStatement ||
        node is WhileStatement ||
        node is DoStatement) {
      final loopBody = node is ForStatement
          ? node.body
          : node is WhileStatement
          ? node.body
          : (node as DoStatement).body;
      result = [...active, ...statement(loopBody, active, visiting)];
    } else {
      // Unsupported control flow cannot prove cleanup; keep an unclosed exit.
      result = active;
      if (node is SwitchStatement) {
        result = [
          ...active,
          for (final path in active) _Path(path.closed, _Exit.returned),
        ];
      }
    }
    // There are only six distinct states; avoid exponential branch growth.
    return {
      for (final path in [...done, ...result]) (path.closed, path.exit),
    }.map((state) => _Path(state.$1, state.$2)).toList();
  }

  List<_Path> expression(
    Expression node,
    List<_Path> paths,
    Set<Element> visiting, {
    bool awaited = false,
  }) {
    if (node is AwaitExpression) {
      return expression(node.expression, paths, visiting, awaited: true);
    }
    if (node is ThrowExpression) {
      return [for (final path in paths) _Path(path.closed, _Exit.thrown)];
    }
    if (node is! MethodInvocation) return paths;
    final target = node.realTarget;
    Element? targetElement;
    if (target is SimpleIdentifier) targetElement = target.element;
    if (target is PropertyAccess && target.target is ThisExpression) {
      targetElement = target.propertyName.element;
    }
    if (targetElement is PropertyAccessorElement) {
      targetElement = targetElement.variable;
    }
    if (node.methodName.name == 'close' && targetElement == field) {
      return [for (final path in paths) _Path(true, path.exit)];
    }
    // Only a resolved call on this instance may establish local helper cleanup.
    if (target != null && target is! ThisExpression) return paths;
    final called = node.methodName.element;
    if (called == null || visiting.contains(called)) return paths;
    final helper = methods
        .where((method) => method.declaredFragment?.element == called)
        .firstOrNull;
    if (helper == null) return paths;
    if (helper.body.isAsynchronous && !awaited) return paths;
    return [
      for (final path in body(helper.body, paths, {...visiting, called}))
        _Path(
          path.closed,
          path.exit == _Exit.returned ? _Exit.active : path.exit,
        ),
    ];
  }
}

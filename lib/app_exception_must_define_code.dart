import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces AppException subclasses to define a stable 'code'
/// for i18n-safe error reporting to users.
///
/// Every exception that can reach the UI must carry a stable, localizable
/// code string so that the presentation layer can look up the translated message
/// instead of exposing a raw exception message.
class AppExceptionMustDefineCode extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [AppExceptionMustDefineCode].
  AppExceptionMustDefineCode() : super(code: _code);

  static const _code = LintCode(
    'app_exception_must_define_code',
    'Los subtipos de AppException deben definir un "code" estable para i18n. '
        'Sin code, la capa de presentación no puede localizar el mensaje de error.',
    correctionMessage:
        'Añade un campo "code" o pásalo al super constructor.\n'
        'Además, evita literales crudos (ej: code: \'save_failed\').\n'
        'Usa constantes estables (ej: I18nCodes.widgetGenericError).\n'
        'Ejemplo:\n'
        '  class NotFoundAppException extends AppException {\n'
        '    NotFoundAppException() : super(code: AppErrorCodes.notFound);\n'
        '  }',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final path = resolver.uri.path;
    if (path.contains('/test/') ||
        path.contains('/integration_test/') ||
        path.endsWith('_test.dart')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Skip abstract classes (they are defining interfaces, not concrete exceptions)
      if (node.abstractKeyword != null) return;

      // Skip private classes
      final className = node.namePart.typeName.lexeme;
      if (className.startsWith('_')) return;

      // Must directly extend AppException
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;
      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'AppException') return;

      if (!_hasCodeDefined(node)) {
        reporter.atNode(node, _code);
      }
    });

    // Extra safety: reject raw string literals used as code in AppException
    // instantiations (e.g. code: 'save_failed').
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!_isAppExceptionInstance(node)) return;
      final NamedArgument? codeArg = _findNamedArg(node.argumentList, 'code');
      if (codeArg == null) return;
      if (codeArg.argumentExpression is StringLiteral ||
          codeArg.argumentExpression is StringInterpolation) {
        reporter.atNode(codeArg.argumentExpression, _code);
      }
    });
  }

  bool _isAppExceptionInstance(InstanceCreationExpression node) {
    final DartType? createdType = node.constructorName.type.type;
    if (createdType is InterfaceType) {
      final elementName = createdType.element.name;
      if (elementName == 'AppException') return true;

      for (final superType in createdType.allSupertypes) {
        if (superType.element.name == 'AppException') {
          return true;
        }
      }
    }

    final typeName = node.constructorName.type.name.lexeme;
    return typeName.endsWith('AppException') ||
        typeName.endsWith('Exception') ||
        typeName.endsWith('Failure');
  }

  NamedArgument? _findNamedArg(ArgumentList args, String name) {
    for (final arg in args.arguments) {
      if (arg is NamedArgument && arg.name.lexeme == name) {
        return arg;
      }
    }
    return null;
  }

  /// Returns true if the class defines or passes a 'code' field/parameter.
  ///
  /// Checks:
  /// - Field declaration named 'code'
  /// - Getter named 'code'
  /// - Constructor parameter named 'code' (including `this.code`)
  /// - Super constructor call with named argument `code:`
  bool _hasCodeDefined(ClassDeclaration node) {
    for (final member in node.body.members) {
      // Field: final String code = '...'; or @override final String code;
      if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          if (variable.name.lexeme == 'code') return true;
        }
      }

      // Getter: String get code => '...';
      if (member is MethodDeclaration &&
          member.isGetter &&
          member.name.lexeme == 'code') {
        return true;
      }

      if (member is ConstructorDeclaration) {
        // Constructor parameter named 'code' (simple or this.code)
        for (final param in member.parameters.parameters) {
          final name = param.name?.lexeme;
          if (name == 'code') return true;
        }

        for (final initializer in member.initializers) {
          if (initializer is SuperConstructorInvocation) {
            for (final arg in initializer.argumentList.arguments) {
              if (arg is NamedArgument && arg.name.lexeme == 'code') {
                return true;
              }
            }
          }
        }
      }
    }
    return false;
  }
}

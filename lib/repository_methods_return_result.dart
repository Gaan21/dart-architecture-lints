import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces Repository methods to return Future<Result<T>> or Result<T>.
/// Ensures consistent error handling across the data layer by using the Result pattern.
class RepositoryMethodsReturnResult extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [RepositoryMethodsReturnResult].
  const RepositoryMethodsReturnResult() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Cambia el tipo de retorno a Future<Result<TipoRetorno>> y envuelve resultados exitosos con Success() o errores con Failure().\n'
        'Ejemplo:\n'
        '  class UserRepositoryImpl implements UserRepository {\n'
        '    @override\n'
        '    Future<Result<User>> getById(String id) async {\n'
        '      try {\n'
        '        final model = await _dataSource.getById(id);\n'
        '        return Success(UserMapper.toEntity(model));\n'
        '      } catch (e) {\n'
        '        return Failure(AppException.fromException(e));\n'
        '      }\n'
        '    }\n'
        '  }',
    name: 'repository_methods_return_result',
    problemMessage:
        'Los métodos de Repository deben retornar Future<Result<T>> o Result<T> para manejo de errores consistente.',
  );

  /// Executes the lint rule to detect Repository methods that do not return Result<T>.
  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final uri = resolver.source.uri;
    final path = uri.path;

    // Solo aplicar en data/repositories/ (incluyendo subcarpetas)
    if (!path.contains('/data/repositories/')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      final className = node.name.lexeme;

      // Solo verificar clases que terminan en "Repository" o "RepositoryImpl"
      if (!className.endsWith('Repository') &&
          !className.endsWith('RepositoryImpl')) {
        return;
      }

      // Verificar métodos públicos de la clase
      for (final member in node.members) {
        if (member is MethodDeclaration) {
          _checkMethod(member, reporter);
        }
      }
    });
  }

  /// Checks if a method declaration returns Result<T> or Future<Result<T>>.
  void _checkMethod(MethodDeclaration method, DiagnosticReporter reporter) {
    // Excluir constructors - verificar nombre de método contra nombre de clase padre
    final parent = method.parent;
    if (parent is ClassDeclaration) {
      if (method.name.lexeme == parent.name.lexeme) {
        return; // Es un constructor
      }
    }

    // Método más robusto: verificar si no tiene tipo de retorno (característica de constructors)
    if (method.returnType == null && method.name.lexeme[0].toUpperCase() == method.name.lexeme[0]) {
      return; // Probablemente un constructor
    }

    // Excluir métodos privados
    final methodName = method.name.lexeme;
    if (methodName.startsWith('_')) {
      return;
    }

    // Excluir métodos abstractos (solo declaraciones de interface)
    if (method.isAbstract) {
      return;
    }

    // Excluir getters síncronos (sin Future)
    if (method.isGetter) {
      final returnType = method.returnType;
      if (returnType == null || !_isFutureType(returnType)) {
        return;
      }
    }

    // Excluir métodos que retornan void o Future<void>
    final returnType = method.returnType;
    if (returnType == null) {
      return; // Sin tipo de retorno explícito, asumir válido
    }

    if (_isVoidOrFutureVoid(returnType)) {
      return;
    }

    // Excluir métodos con @override de Object (toString, hashCode, ==)
    if (_isObjectOverride(method)) {
      return;
    }

    // Verificar si retorna Result<T> o Future<Result<T>>
    if (!_returnsResult(returnType)) {
      reporter.atNode(method, _code);
    }
  }

  /// Checks if the return type is void or Future<void>.
  bool _isVoidOrFutureVoid(TypeAnnotation returnType) {
    if (returnType is NamedType) {
      final typeName = returnType.name.lexeme;

      // void directo
      if (typeName == 'void') {
        return true;
      }

      // Future<void>
      if (typeName == 'Future') {
        final typeArgs = returnType.typeArguments?.arguments;
        if (typeArgs != null && typeArgs.isNotEmpty) {
          final firstArg = typeArgs.first;
          if (firstArg is NamedType &&
              firstArg.name.lexeme == 'void') {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Checks if the return type is Future<...>.
  bool _isFutureType(TypeAnnotation returnType) {
    if (returnType is NamedType) {
      return returnType.name.lexeme == 'Future';
    }
    return false;
  }

  /// Checks if the method overrides Object methods (toString, hashCode, ==).
  bool _isObjectOverride(MethodDeclaration method) {
    final methodName = method.name.lexeme;
    final objectMethods = {'toString', 'hashCode', 'noSuchMethod'};

    if (objectMethods.contains(methodName)) {
      return true;
    }

    // Operador ==
    if (method.isOperator && methodName == '==') {
      return true;
    }

    return false;
  }

  /// Checks if the return type is Result<T> or Future<Result<T>>.
  bool _returnsResult(TypeAnnotation returnType) {
    if (returnType is NamedType) {
      final typeName = returnType.name.lexeme;

      // Result<T> directo
      if (typeName == 'Result') {
        return true;
      }

      // Future<Result<T>>
      if (typeName == 'Future') {
        final typeArgs = returnType.typeArguments?.arguments;
        if (typeArgs != null && typeArgs.isNotEmpty) {
          final firstArg = typeArgs.first;
          if (firstArg is NamedType &&
              firstArg.name.lexeme == 'Result') {
            return true;
          }
        }
      }
    }

    return false;
  }
}

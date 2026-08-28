import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces DataSource methods to return Future<Result<T>>, Result<T>, or Stream<Result<T>>.
/// Ensures consistent error handling across the data layer by using the Result pattern.
class DataSourcesReturnResult extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [DataSourcesReturnResult].
  const DataSourcesReturnResult() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Cambia el tipo de retorno a Future<Result<TipoRetorno>> y envuelve con Success() para datos exitosos o Failure() para errores.\n'
        'Ejemplo:\n'
        '  class UserLocalDataSourceImpl implements UserLocalDataSource {\n'
        '    final Database _db;\n\n'
        '    @override\n'
        '    Future<Result<List<UserModel>>> getUsers() async {\n'
        '      try {\n'
        '        final rows = await _db.query(\'users\');\n'
        '        final models = rows.map(UserModel.fromRow).toList();\n'
        '        return Success(models);\n'
        '      } catch (e) {\n'
        '        return Failure(StorageException(\'Failed to load users: \$e\'));\n'
        '      }\n'
        '    }\n'
        '  }',
    name: 'datasources_return_result',
    problemMessage:
        'Los métodos de DataSource deben retornar Future<Result<T>>, Result<T>, o Stream<Result<T>> para manejo de errores consistente en la data layer.',
  );

  /// Executes the lint rule to detect DataSource methods that do not return Result<T>.
  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final uri = resolver.source.uri;
    final path = uri.path;

    // Solo aplicar en data/dataSources/local/ y data/dataSources/remote/
    if (!path.contains('/data/dataSources/')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      final className = node.name.lexeme;

      // Solo verificar clases que terminan en "DataSource" o implementan XDataSource
      if (!className.endsWith('DataSource') &&
          !className.endsWith('DataSourceImpl')) {
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

  /// Checks if a method declaration returns Result<T>, Future<Result<T>>, or Stream<Result<T>>.
  void _checkMethod(MethodDeclaration method, DiagnosticReporter reporter) {
    // Excluir constructors - verificar nombre de método contra nombre de clase padre
    final parent = method.parent;
    if (parent is ClassDeclaration) {
      if (method.name.lexeme == parent.name.lexeme) {
        return; // Es un constructor
      }
    }

    // Método más robusto: verificar si no tiene tipo de retorno (característica de constructors)
    if (method.returnType == null &&
        method.name.lexeme[0].toUpperCase() == method.name.lexeme[0]) {
      return; // Probablemente un constructor
    }

    // Excluir métodos privados
    final methodName = method.name.lexeme;
    if (methodName.startsWith('_')) {
      return;
    }

    // Excluir getters síncronos simples (configuración, sin Future/Stream)
    if (method.isGetter) {
      final returnType = method.returnType;
      if (returnType == null ||
          (!_isFutureType(returnType) && !_isStreamType(returnType))) {
        return;
      }
    }

    // Excluir métodos que retornan void, Future<void>, o Stream<void>
    final returnType = method.returnType;
    if (returnType == null) {
      return; // Sin tipo de retorno explícito, asumir válido
    }

    if (_isVoidOrFutureVoidOrStreamVoid(returnType)) {
      return;
    }

    // Excluir métodos con @override de Object (toString, hashCode, ==)
    if (_isObjectOverride(method)) {
      return;
    }

    // Verificar si retorna Result<T>, Future<Result<T>>, o Stream<Result<T>>
    if (!_returnsResult(returnType)) {
      reporter.atNode(method, _code);
    }
  }

  /// Checks if the return type is void, Future<void>, or Stream<void>.
  bool _isVoidOrFutureVoidOrStreamVoid(TypeAnnotation returnType) {
    if (returnType is NamedType) {
      final typeName = returnType.name.lexeme;

      // void directo
      if (typeName == 'void') {
        return true;
      }

      // Future<void> o Stream<void>
      if (typeName == 'Future' || typeName == 'Stream') {
        final typeArgs = returnType.typeArguments?.arguments;
        if (typeArgs != null && typeArgs.isNotEmpty) {
          final firstArg = typeArgs.first;
          if (firstArg is NamedType && firstArg.name.lexeme == 'void') {
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

  /// Checks if the return type is Stream<...>.
  bool _isStreamType(TypeAnnotation returnType) {
    if (returnType is NamedType) {
      return returnType.name.lexeme == 'Stream';
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

  /// Checks if the return type is Result<T>, Future<Result<T>>, or Stream<Result<T>>.
  bool _returnsResult(TypeAnnotation returnType) {
    if (returnType is NamedType) {
      final typeName = returnType.name.lexeme;

      // Result<T> directo
      if (typeName == 'Result') {
        return true;
      }

      // Future<Result<T>> o Stream<Result<T>>
      if (typeName == 'Future' || typeName == 'Stream') {
        final typeArgs = returnType.typeArguments?.arguments;
        if (typeArgs != null && typeArgs.isNotEmpty) {
          final firstArg = typeArgs.first;
          if (firstArg is NamedType && firstArg.name.lexeme == 'Result') {
            return true;
          }
        }
      }
    }

    return false;
  }
}

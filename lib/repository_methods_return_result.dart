import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:dart_architecture_lints/result_return_types.dart';

/// Requires public repository operations to return `Result` (directly or via
/// `Future`/`FutureOr`/`Stream`). Synchronous getters and private helpers may
/// return values directly; this is a signature check, not a proof of semantics.
class RepositoryMethodsReturnResult extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [RepositoryMethodsReturnResult].
  RepositoryMethodsReturnResult() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'repository_methods_return_result',
    'Los métodos de Repository deben retornar Future<Result<T>> o Result<T> para manejo de errores consistente.',
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
  );

  /// Executes the lint rule to detect Repository methods that do not return `Result`.
  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final uri = resolver.uri;
    final path = uri.path;

    // Solo aplicar en data/repositories/ (incluyendo subcarpetas)
    if (!path.contains('/data/repositories/')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      final className = node.namePart.typeName.lexeme;

      // Solo verificar clases que terminan en "Repository" o "RepositoryImpl"
      if (!className.endsWith('Repository') &&
          !className.endsWith('RepositoryImpl')) {
        return;
      }

      // Verificar métodos públicos de la clase
      for (final member in node.body.members) {
        if (member is MethodDeclaration) {
          _checkMethod(member, reporter);
        }
      }
    });
  }

  /// Reports members that violate the shared Result return contract.
  void _checkMethod(MethodDeclaration method, DiagnosticReporter reporter) {
    if (violatesResultReturn(method, checkAbstract: false)) {
      reporter.atNode(method, _code);
    }
  }
}

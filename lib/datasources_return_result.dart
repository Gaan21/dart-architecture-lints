import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:dart_architecture_lints/result_return_types.dart';

/// Requires public data-source operations, including abstract declarations, to
/// return `Result` (directly or via `Future`/`FutureOr`/`Stream`). Synchronous
/// getters and private helpers may return values directly.
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

  /// Executes the lint rule to detect DataSource methods that do not return `Result`.
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

  /// Reports members that violate the shared Result return contract.
  void _checkMethod(MethodDeclaration method, DiagnosticReporter reporter) {
    if (violatesResultReturn(method, checkAbstract: true)) {
      reporter.atNode(method, _code);
    }
  }
}

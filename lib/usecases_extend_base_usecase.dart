import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces UseCases to extend BaseUseCase.
/// UseCases must extend `BaseUseCase<T, P>` for consistent error handling and `Result<T>` conversion.
class UseCasesExtendBaseUseCase extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [UseCasesExtendBaseUseCase].
  UseCasesExtendBaseUseCase() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'usecases_extend_base_usecase',
    'Los UseCases deben extender BaseUseCase<T, P> para manejo consistente de errores y conversión a Result<T>.',
    correctionMessage:
        'Extiende BaseUseCase<TipoRetorno, TipoParams> y usa executeGuard(() => ...) para envolver operaciones que puedan fallar.\n'
        'Ejemplo:\n'
        '  class GetUserUseCase extends BaseUseCase<User, String> {\n'
        '    final UserRepository _repo;\n'
        '    GetUserUseCase(this._repo);\n'
        '    @override\n'
        '    Future<Result<User>> execute(String id) async {\n'
        '      return executeGuard(() => _repo.getById(id));\n'
        '    }\n'
        '  }',
  );

  /// Executes the lint rule to detect UseCases that do not extend BaseUseCase.
  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final uri = resolver.uri;
    final path = uri.path;

    // Solo aplicar en domain/useCases/ (incluyendo subcarpetas)
    if (!path.contains('/domain/useCases/')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Ignorar clases abstractas que definen interfaces o bases
      if (node.abstractKeyword != null) {
        return;
      }

      // Solo verificar clases que terminan en "UseCase"
      final className = node.namePart.typeName.lexeme;
      if (!className.endsWith('UseCase')) {
        return;
      }

      // Ignorar clases privadas (comienzan con _)
      if (className.startsWith('_')) {
        return;
      }

      // Verificar si extiende BaseUseCase
      final extendsClause = node.extendsClause;
      if (extendsClause == null) {
        reporter.atNode(node, _code);
        return;
      }

      final superclassName = extendsClause.superclass.name.toString();
      if (superclassName != 'BaseUseCase') {
        reporter.atNode(node, _code);
      }
    });
  }
}

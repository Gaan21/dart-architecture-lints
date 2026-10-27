import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces ViewModels to extend BaseViewModel or BaseViewModelWithEffects.
/// ViewModels must use typed state pattern with `UiState<T>` for consistent state management.
class ViewModelsExtendBaseViewModel extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [ViewModelsExtendBaseViewModel].
  ViewModelsExtendBaseViewModel() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'viewmodels_extend_base_viewmodel',
    'Los ViewModels deben extender BaseViewModel<T> o BaseViewModelWithEffects<T> para estado tipado y manejo consistente.',
    correctionMessage:
        'Cambia "extends ChangeNotifier" por "extends BaseViewModel<TipoDato>" y usa setState(UiState.data(value)) para actualizar estado.\n'
        'Para ViewModels con efectos efímeros (navegación, snackbars), usa "extends BaseViewModelWithEffects<TipoDato>".\n'
        'Ejemplo:\n'
        '  class UserViewModel extends BaseViewModel<User> {\n'
        '    final GetUserUseCase _getUserUseCase;\n'
        '    UserViewModel(this._getUserUseCase);\n'
        '    \n'
        '    Future<void> loadUser() async {\n'
        '      setState(UiState.loading());\n'
        '      final result = await _getUserUseCase.execute(NoParams());\n'
        '      handleResult(result); // Auto-actualiza a data/error\n'
        '    }\n'
        '  }',
  );

  /// Executes the lint rule to detect ViewModels that do not extend BaseViewModel.
  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final uri = resolver.uri;
    final path = uri.path;

    // Solo aplicar en presentation/viewModels/ (incluyendo subcarpetas)
    if (!path.contains('/presentation/viewModels/')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Ignorar clases abstractas que definen interfaces o bases
      if (node.abstractKeyword != null) {
        return;
      }

      // Solo verificar clases que terminan en "ViewModel"
      final className = node.namePart.typeName.lexeme;
      if (!className.endsWith('ViewModel')) {
        return;
      }

      // Ignorar clases privadas (comienzan con _)
      if (className.startsWith('_')) {
        return;
      }

      // Verificar si extiende BaseViewModel o BaseViewModelWithEffects
      final extendsClause = node.extendsClause;
      if (extendsClause == null) {
        reporter.atNode(node, _code);
        return;
      }

      final superclassName = extendsClause.superclass.name.lexeme;

      // Aceptar BaseViewModel y BaseViewModelWithEffects
      final acceptedBaseClasses = {'BaseViewModel', 'BaseViewModelWithEffects'};

      if (!acceptedBaseClasses.contains(superclassName)) {
        // Si extiende ChangeNotifier directamente u otra clase, reportar error
        reporter.atNode(node, _code);
      }
    });
  }
}

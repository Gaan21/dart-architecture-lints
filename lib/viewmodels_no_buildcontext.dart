import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prevents ViewModels from containing BuildContext references.
/// Enforces separation between UI and business logic in MVVM architecture.
class ViewModelsNoBuildContextLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [ViewModelsNoBuildContextLint].
  ViewModelsNoBuildContextLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'viewmodels_no_buildcontext',
    'ViewModel contiene referencia a BuildContext, violando arquitectura MVVM. Los ViewModels deben ser UI-agnostic para mejor testabilidad.',
    correctionMessage:
        'Elimina BuildContext del ViewModel. Para navegación: usa effects/events que escucha el Widget. Para datos: usa state properties.\n'
        'Ejemplo:\n'
        '  // ❌ void navigate(BuildContext context) { ... }\n'
        '  // ✅ void navigateToDetail(String id) {\n'
        '  //     emitEffect(NavigateToDetailEffect(id: id));\n'
        '  //   }',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Only check ViewModel classes
      if (!_isViewModelClass(node)) return;

      // Check fields for BuildContext
      _checkFields(node, reporter);

      // Check constructor parameters for BuildContext
      _checkConstructorParameters(node, reporter);
    });
  }

  /// Checks if a class is a ViewModel class.
  bool _isViewModelClass(ClassDeclaration classDecl) {
    final className = classDecl.namePart.typeName.lexeme;

    // Check if class name contains "ViewModel"
    if (className.contains('ViewModel')) return true;

    // Check if it extends/implements common ViewModel base classes
    return _extendsViewModelBase(classDecl);
  }

  /// Checks if class extends common ViewModel base classes.
  bool _extendsViewModelBase(ClassDeclaration classDecl) {
    final extendsClause = classDecl.extendsClause;
    if (extendsClause != null) {
      final superClassName = extendsClause.superclass.name.lexeme;
      if (_isViewModelBaseClass(superClassName)) return true;
    }

    final implementsClause = classDecl.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        if (_isViewModelBaseClass(interface.name.lexeme)) return true;
      }
    }

    return false;
  }

  /// Checks if a class name is a known ViewModel base class.
  bool _isViewModelBaseClass(String className) {
    const viewModelBases = {
      'ChangeNotifier',
      'ValueNotifier',
      'Cubit',
      'Bloc',
      'BaseViewModel',
      'ViewModel',
    };

    return viewModelBases.contains(className);
  }

  /// Checks class fields for BuildContext references.
  void _checkFields(ClassDeclaration classDecl, DiagnosticReporter reporter) {
    for (final member in classDecl.body.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type != null && _isBuildContextType(type)) {
          reporter.atNode(member, _code);
        }
      }
    }
  }

  /// Checks constructor parameters for BuildContext references.
  void _checkConstructorParameters(
    ClassDeclaration classDecl,
    DiagnosticReporter reporter,
  ) {
    for (final member in classDecl.body.members) {
      if (member is ConstructorDeclaration) {
        final parameters = member.parameters;

        // Check normal parameters
        for (final param in parameters.parameters) {
          // A plain (not field, super or function-typed) parameter, with or
          // without a default value; reported over the whole parameter.
          if (param is RegularFormalParameter &&
              param.functionTypedSuffix == null) {
            final type = param.type;
            if (type != null && _isBuildContextType(type)) {
              reporter.atNode(param, _code);
            }
          }
        }
      }
    }
  }

  /// Checks if a type annotation represents BuildContext.
  bool _isBuildContextType(TypeAnnotation typeAnnotation) {
    if (typeAnnotation is NamedType) {
      final typeName = typeAnnotation.name.lexeme;
      return typeName == 'BuildContext';
    }
    return false;
  }
}

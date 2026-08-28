import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prevents ViewModels from using Flutter-specific types
/// (TextEditingController, FocusNode, GlobalKey, etc.).
///
/// ViewModels should be UI-agnostic for better testability without flutter_test.
/// Flutter types should go in UiState classes.
class ViewModelsNoFlutterTypesLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [ViewModelsNoFlutterTypesLint].
  const ViewModelsNoFlutterTypesLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    name: 'viewmodels_no_flutter_types',
    problemMessage:
        'ViewModel should not use Flutter types (TextEditingController, FocusNode, GlobalKey, etc.). This couples ViewModel to Flutter and makes testing difficult.',
    correctionMessage:
        'Move Flutter types to UiState class. ViewModel should be UI-agnostic and testable without flutter_test.',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Only check ViewModel classes
      if (!_isViewModelClass(node)) return;

      // Check fields for Flutter types
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final type = member.fields.type;
          if (type != null && _isFlutterType(type)) {
            reporter.atNode(member, _code);
          }
        }
      }
    });
  }

  /// Checks if a class is a ViewModel class.
  bool _isViewModelClass(ClassDeclaration classDecl) {
    final className = classDecl.name.lexeme;
    return className.contains('ViewModel');
  }

  /// Checks if the type is a Flutter-specific type.
  bool _isFlutterType(TypeAnnotation type) {
    if (type is! NamedType) return false;

    final typeName = type.name.lexeme;

    // Exception: GlobalKey<NavigatorState> is allowed for tab navigation
    if (typeName == 'GlobalKey') {
      final typeArgs = type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final firstArg = typeArgs.arguments.first;
        if (firstArg is NamedType && firstArg.name.lexeme == 'NavigatorState') {
          return false;  // ✅ Allow GlobalKey<NavigatorState>
        }
      }
    }

    // Note: BuildContext is already covered by viewmodels_no_buildcontext rule
    const flutterTypes = {
      'TextEditingController',
      'ScrollController',
      'AnimationController',
      'TabController',
      'PageController',
      'FocusNode',
      'GlobalKey',  // GlobalKey without NavigatorState is still prohibited
      'Color',
      'TextStyle',
      'EdgeInsets',
      'BorderRadius',
      'BoxDecoration',
      'Widget',
      'StatelessWidget',
      'StatefulWidget',
    };

    return flutterTypes.contains(typeName);
  }
}

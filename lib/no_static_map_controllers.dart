import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'resource_types.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prohibits static Map fields containing Flutter controllers
/// or resources with lifecycle (TextEditingController, Timer, FocusNode, etc.).
///
/// This prevents memory leaks and lifecycle management issues that occur when
/// controllers are stored in static Maps instead of being properly scoped
/// to their owning widgets or state classes.
class NoStaticMapControllersLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoStaticMapControllersLint].
  const NoStaticMapControllersLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    name: 'no_static_map_controllers',
    problemMessage:
        'Map estático con controllers/resources con lifecycle (TextEditingController, Timer, FocusNode, etc.) causa memory leaks y problemas de lifecycle.',
    correctionMessage:
        'Mueve controllers a ChangeNotifier (UiState) con Provider scoped.\n'
        'Ejemplo:\n'
        '  class SearchUiState extends ChangeNotifier {\n'
        '    final controller = TextEditingController();\n'
        '    @override\n'
        '    void dispose() {\n'
        '      controller.dispose();\n'
        '      super.dispose();\n'
        '    }\n'
        '  }',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      // Check if field is static
      if (!node.isStatic) return;

      // Check if the field type is a Map containing lifecycle resources
      if (node.fields.variables.any((variable) {
        final type = variable.declaredFragment?.element.type;
        return type is InterfaceType &&
            type.isDartCoreMap &&
            type.typeArguments.length == 2 &&
            isResourceType(type.typeArguments[1], lifecycleResourceNames);
      })) {
        reporter.atNode(node, _code);
      }
    });
  }
}

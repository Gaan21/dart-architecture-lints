import 'package:analyzer/dart/ast/ast.dart';
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
      final type = node.fields.type;
      if (type == null) return;

      if (_isMapWithLifecycleResources(type)) {
        reporter.atNode(node, _code);
      }
    });
  }

  /// Checks if the type is a Map containing lifecycle resources.
  bool _isMapWithLifecycleResources(TypeAnnotation type) {
    if (type is! NamedType) return false;

    final typeName = type.name.lexeme;

    // Check if it's a Map type
    if (typeName != 'Map') return false;

    // Check type arguments (Map<K, V>)
    final typeArgs = type.typeArguments;
    if (typeArgs == null || typeArgs.arguments.length < 2) return false;

    // Check the value type (second type argument)
    final valueType = typeArgs.arguments[1];
    if (valueType is! NamedType) return false;

    final valueTypeName = valueType.name.lexeme;

    // List of types that represent lifecycle resources
    const lifecycleResources = {
      'TextEditingController',
      'ScrollController',
      'AnimationController',
      'TabController',
      'PageController',
      'FocusNode',
      'Timer',
      'StreamController',
      'StreamSubscription',
    };

    return lifecycleResources.contains(valueTypeName);
  }
}

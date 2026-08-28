import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prevents mixins from owning resources with lifecycle
/// (TextEditingController, Timer, FocusNode, ScrollController, etc.).
///
/// Mixins should only provide behavior, not own stateful resources.
/// Resources must be owned by proper state containers (UiState, ChangeNotifier)
/// that can be disposed correctly.
class MixinNoStateOwnershipLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [MixinNoStateOwnershipLint].
  const MixinNoStateOwnershipLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    name: 'mixin_no_state_ownership',
    problemMessage:
        'Mixin no debe poseer resources con lifecycle (TextEditingController, Timer, FocusNode, etc.). Los mixins deben ser stateless y solo proveer comportamiento.',
    correctionMessage:
        'Mueve ownership a ChangeNotifier (UiState) y accede vía BuildContext.\n'
        'Ejemplo en mixin:\n'
        '  void search(BuildContext context) {\n'
        '    final ctrl = context.read<SearchUiState>().controller;\n'
        '    // usar ctrl...\n'
        '  }',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMixinDeclaration((MixinDeclaration node) {
      // Check all fields in the mixin
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final type = member.fields.type;
          if (type != null && _isLifecycleResource(type)) {
            reporter.atNode(member, _code);
          }
        }
      }
    });
  }

  /// Checks if the type represents a lifecycle resource.
  bool _isLifecycleResource(TypeAnnotation type) {
    if (type is! NamedType) return false;

    final typeName = type.name.lexeme;

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
      'VideoPlayerController',
      'CameraController',
    };

    return lifecycleResources.contains(typeName);
  }
}

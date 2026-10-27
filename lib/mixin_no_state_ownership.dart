import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

import 'resource_types.dart';

/// A lint rule that prevents mixins from owning resources with lifecycle
/// (TextEditingController, Timer, FocusNode, ScrollController, etc.).
///
/// Mixins should only provide behavior, not own stateful resources.
/// Resources must be owned by proper state containers (UiState, ChangeNotifier)
/// that can be disposed correctly.
class MixinNoStateOwnershipLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [MixinNoStateOwnershipLint].
  MixinNoStateOwnershipLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'mixin_no_state_ownership',
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
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addMixinDeclaration((MixinDeclaration node) {
      // Check all fields in the mixin
      for (final member in node.body.members) {
        if (member is FieldDeclaration) {
          if (member.fields.variables.any(
            (variable) => isResourceType(
              variable.declaredFragment?.element.type,
              lifecycleResourceNames,
            ),
          )) {
            reporter.atNode(member, _code);
          }
        }
      }
    });
  }
}

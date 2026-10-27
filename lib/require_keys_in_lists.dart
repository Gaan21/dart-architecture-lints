import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that requires keys in dynamic ListView and GridView items.
/// When ListView.builder or GridView.builder items don't have keys, this rule suggests adding them.
class RequireKeysInListsLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [RequireKeysInListsLint].
  RequireKeysInListsLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'require_keys_in_lists',
    'Consider stable item keys when list items can move, be inserted, or be removed. Keys preserve identity; they do not prevent rebuilds.',
    correctionMessage: 'Use a stable ValueKey based on item identity (or ObjectKey when object identity is stable). Do not create a fresh UniqueKey on each build.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      // Check if this is a ListView.builder or GridView.builder call
      if (_isDynamicListView(node)) {
        _checkItemBuilderForKeys(node, reporter);
      }
    });
  }

  /// Checks if the instance creation is a dynamic list view (ListView.builder, GridView.builder).
  bool _isDynamicListView(InstanceCreationExpression node) {
    final constructorName = node.constructorName.toString();
    return constructorName == 'ListView.builder' ||
        constructorName == 'GridView.builder';
  }

  /// Checks the itemBuilder parameter for widgets without keys.
  void _checkItemBuilderForKeys(
    InstanceCreationExpression node,
    DiagnosticReporter reporter,
  ) {
    final arguments = node.argumentList.arguments;

    for (final argument in arguments) {
      // Look for itemBuilder named parameter
      if (argument is NamedArgument && argument.name.lexeme == 'itemBuilder') {
        _analyzeItemBuilderFunction(argument.argumentExpression, reporter);
        break;
      }
    }
  }

  /// Analyzes the itemBuilder function to check if returned widgets have keys.
  void _analyzeItemBuilderFunction(
    Expression itemBuilderExpr,
    DiagnosticReporter reporter,
  ) {
    if (itemBuilderExpr is! FunctionExpression) return;

    final functionBody = itemBuilderExpr.body;
    if (functionBody is! ExpressionFunctionBody) return;

    final returnedExpression = functionBody.expression;

    // Check if the returned widget has a key parameter
    if (_isWidgetWithoutKey(returnedExpression)) {
      reporter.atNode(returnedExpression, _code);
    }
  }

  /// Checks if an expression is a widget instance creation without a key.
  bool _isWidgetWithoutKey(Expression expression) {
    if (expression is! InstanceCreationExpression) return false;

    // Check if it's a Flutter widget
    if (!_isFlutterWidget(expression)) return false;

    // Check if it already has a key parameter
    final arguments = expression.argumentList.arguments;
    for (final argument in arguments) {
      if (argument is NamedArgument && argument.name.lexeme == 'key') {
        return false; // Already has a key
      }
    }

    return true; // Widget without key
  }

  /// Checks if the constructor creates a Flutter widget.
  bool _isFlutterWidget(InstanceCreationExpression node) {
    final type = node.constructorName.type.type;
    if (type == null) return false;

    final element = type.element;
    if (element is! ClassElement) return false;

    // Common widgets that are typically used in lists
    final commonListWidgets = {
      'ListTile',
      'Card',
      'Container',
      'Text',
      'Row',
      'Column',
      'Padding',
      'SizedBox',
      'Expanded',
      'Flexible',
      'DecoratedBox',
      'InkWell',
      'GestureDetector',
      'Material',
      'Ink',
      'Stack',
      'Positioned',
      'Center',
      'Align',
      'AspectRatio',
      'Hero',
    };

    if (commonListWidgets.contains(element.name)) return true;

    // Check inheritance chain for Widget
    return _extendsWidget(element);
  }

  /// Recursively checks if a class extends Widget.
  bool _extendsWidget(ClassElement element) {
    // Check direct supertype
    final supertype = element.supertype;
    if (supertype == null) return false;

    final supertypeElement = supertype.element;
    final supertypeName = supertypeElement.name;
    if (supertypeName == 'Widget' ||
        supertypeName == 'StatelessWidget' ||
        supertypeName == 'StatefulWidget') {
      return true;
    }

    // Check parent's inheritance (limit depth to avoid infinite recursion)
    if (element.name != 'Object' && supertypeElement is ClassElement) {
      return _extendsWidget(supertypeElement);
    }

    return false;
  }
}

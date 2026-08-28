import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that flags variables with very generic names when they could be more descriptive,
/// enhancing readability when the class name provides important context.
class VariableNameShouldMatchClassName extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [VariableNameShouldMatchClassName].
  const VariableNameShouldMatchClassName() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    name: 'variable_name_should_contain_class_name',
    problemMessage:
        'Variable name "{0}" should include the class name "{1}" for clarity.',
    correctionMessage:
        'Use a camelCase name that includes the class name. Example: dashboardViewModel for DashboardViewModel.',
  );

  /// Executes the lint rule and applies the validation for variable naming conventions.
  @override
  void runOnNonGenerated(CustomLintResolver resolver,
      DiagnosticReporter reporter, CustomLintContext context) {
    context.registry.addVariableDeclarationList(
        (VariableDeclarationList variableDeclarationList) {
      for (VariableDeclaration variableDeclaration
          in variableDeclarationList.variables) {
        final DartType? dartType =
            variableDeclaration.declaredFragment?.element.type;

        final String? className = _extractRelevantClassName(dartType);
        if (className == null) continue;

        final String variableName = variableDeclaration.name.lexeme;

        if (_isDocumentedCallbackVariable(variableDeclarationList)) {
          continue;
        }

        if (!_containsClassName(variableName, className)) {
          reporter.atNode(
            variableDeclarationList,
            _code,
            arguments: [variableName, className],
          );
        }
      }
    });
  }

  /// Checks if the provided [type] is a primitive type.
  bool _isPrimitiveType(DartType? type) {
    if (type == null) return true;
    final primitiveTypes = {
      'int',
      'double',
      'bool',
      'String',
      'num',
      'void',
      'Object',
      'dynamic',
      'Widget'
    };

    final String typeName = type.getDisplayString().replaceAll('?', '');

    return primitiveTypes.contains(typeName);
  }

  String? _extractRelevantClassName(DartType? type) {
    if (type == null || _isPrimitiveType(type)) return null;
    if (type is! InterfaceType) return null;

    final String typeName = type.element.displayName;

    if (_isWrapperType(typeName)) {
      for (final DartType arg in type.typeArguments) {
        final String? nestedClassName = _extractRelevantClassName(arg);
        if (nestedClassName != null) return nestedClassName;
      }
      return null;
    }

    return typeName;
  }

  bool _isWrapperType(String typeName) {
    const wrapperTypes = {
      'List',
      'Set',
      'Map',
      'Iterable',
      'Future',
      'Stream',
      'ValueNotifier',
      'ChangeNotifier',
      'Notifier',
    };
    return wrapperTypes.contains(typeName);
  }

  bool _containsClassName(String variableName, String className) {
    final String normalizedVariableName =
        variableName.replaceAll('_', '').toLowerCase();
    final String normalizedClassName =
        className.replaceAll('_', '').toLowerCase();

    return normalizedVariableName.contains(normalizedClassName);
  }

  bool _isDocumentedCallbackVariable(
      VariableDeclarationList variableDeclarationList) {
    if (!_isInCallbackOrLambda(variableDeclarationList)) return false;
    return _hasPrecedingComment(variableDeclarationList);
  }

  bool _isInCallbackOrLambda(AstNode node) {
    return node.thisOrAncestorOfType<FunctionExpression>() != null &&
        node.thisOrAncestorOfType<MethodDeclaration>() == null;
  }

  bool _hasPrecedingComment(VariableDeclarationList node) {
    final Token? commentToken = node.beginToken.precedingComments;
    return commentToken != null;
  }
}

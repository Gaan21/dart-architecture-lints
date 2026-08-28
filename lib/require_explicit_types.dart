import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces explicit type annotations on all variables.
/// Prohibits type inference to improve code readability and maintainability.
class RequireExplicitTypes extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [RequireExplicitTypes].
  const RequireExplicitTypes() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Añade type annotation explícita a la variable.\n'
        'Ejemplos:\n'
        '  // Fields\n'
        '  final StreamController<String> _controller = StreamController<String>();\n'
        '  final int _count = 0;\n'
        '  \n'
        '  // Variables locales\n'
        '  final Result<User> result = await _useCase.execute();\n'
        '  final String name = user.name;\n'
        '  \n'
        '  // Loop variables\n'
        '  for (int i = 0; i < 10; i++) { }\n'
        '  for (final User user in users) { }',
    name: 'require_explicit_types',
    problemMessage:
        'Las variables deben tener type annotation explícita. Usa "final Type name = value;" en lugar de type inference.',
  );

  /// Executes the lint rule to detect variables without explicit type annotations.
  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Detectar fields de clase sin type annotation
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      _checkFieldDeclaration(node, reporter);
    });

    // Detectar variables locales sin type annotation
    context.registry.addVariableDeclarationStatement(
      (VariableDeclarationStatement node) {
        _checkVariableDeclarationStatement(node, reporter);
      },
    );

    // Detectar loop variables sin type annotation
    context.registry.addForStatement((ForStatement node) {
      _checkForStatement(node, reporter);
    });

    context.registry.addForElement((ForElement node) {
      _checkForElement(node, reporter);
    });
  }

  /// Checks if a field declaration has explicit type annotation.
  void _checkFieldDeclaration(
    FieldDeclaration node,
    DiagnosticReporter reporter,
  ) {
    final fields = node.fields;

    // Si no tiene type annotation explícita → reportar error
    if (fields.type == null) {
      // Reportar en cada variable del field
      for (final variable in fields.variables) {
        reporter.atNode(variable, _code);
      }
    }
  }

  /// Checks if a variable declaration statement has explicit type annotation.
  void _checkVariableDeclarationStatement(
    VariableDeclarationStatement node,
    DiagnosticReporter reporter,
  ) {
    final variables = node.variables;

    // Si no tiene type annotation explícita → reportar error
    if (variables.type == null) {
      // Reportar en cada variable
      for (final variable in variables.variables) {
        reporter.atNode(variable, _code);
      }
    }
  }

  /// Checks if a for-statement loop variable has explicit type annotation.
  void _checkForStatement(
    ForStatement node,
    DiagnosticReporter reporter,
  ) {
    final forLoopParts = node.forLoopParts;

    // For loop tradicional: for (int i = 0; i < 10; i++)
    if (forLoopParts is ForPartsWithDeclarations) {
      final variables = forLoopParts.variables;

      // Si no tiene type annotation explícita → reportar error
      if (variables.type == null) {
        for (final variable in variables.variables) {
          reporter.atNode(variable, _code);
        }
      }
    }

    // For-in loop: for (var item in list)
    if (forLoopParts is ForEachPartsWithDeclaration) {
      final loopVariable = forLoopParts.loopVariable;

      // Si no tiene type annotation explícita → reportar error
      if (loopVariable.type == null) {
        reporter.atNode(loopVariable, _code);
      }
    }
  }

  /// Checks if a for-element (in collections) has explicit type annotation.
  void _checkForElement(
    ForElement node,
    DiagnosticReporter reporter,
  ) {
    final forLoopParts = node.forLoopParts;

    // For loop en colección: [for (int i = 0; i < 10; i++) i]
    if (forLoopParts is ForPartsWithDeclarations) {
      final variables = forLoopParts.variables;

      if (variables.type == null) {
        for (final variable in variables.variables) {
          reporter.atNode(variable, _code);
        }
      }
    }

    // For-in en colección: [for (var item in list) item.name]
    if (forLoopParts is ForEachPartsWithDeclaration) {
      final loopVariable = forLoopParts.loopVariable;

      if (loopVariable.type == null) {
        reporter.atNode(loopVariable, _code);
      }
    }
  }
}

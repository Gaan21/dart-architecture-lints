import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:analyzer/dart/element/type.dart';
import 'timezone_safety_utils.dart';

/// Explicit annotations under a strict legacy or selective boundary policy.
class RequireExplicitTypes extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [RequireExplicitTypes].
  const RequireExplicitTypes({
    this.policy = 'strict',
    this.localNames = const [],
  }) : super(code: _code);

  final String policy;
  final List<String> localNames;

  static RequireExplicitTypes fromConfigs(CustomLintConfigs configs) {
    final options = readRuleOptions(configs, _code.name);
    final policy = options['policy'] ?? 'strict';
    if (policy != 'strict' && policy != 'selective') {
      throw ArgumentError.value(policy, 'policy', 'Use strict or selective');
    }
    return RequireExplicitTypes(
      policy: policy as String,
      localNames: readStringListOption(options, 'local_names'),
    );
  }

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage: 'Add a type annotation at this selected boundary.',
    name: 'require_explicit_types',
    problemMessage:
        'An explicit type is required by the configured typing policy.',
  );

  /// Executes the lint rule to detect variables without explicit type annotations.
  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (policy == 'selective') {
      context.registry.addMethodDeclaration((node) {
        if (_public(node.name.lexeme, node) &&
            node.returnType == null &&
            !node.isSetter) {
          reporter.atToken(node.name, _code);
        }
      });
      context.registry.addFunctionDeclaration((node) {
        if (node.parent is CompilationUnit &&
            _public(node.name.lexeme, node) &&
            node.returnType == null &&
            !node.isSetter) {
          reporter.atToken(node.name, _code);
        }
      });
      context.registry.addSimpleFormalParameter((node) {
        if (_publicSignature(node) && node.type == null) {
          reporter.atNode(node, _code);
        }
      });
      context.registry.addTopLevelVariableDeclaration((node) {
        if (node.variables.type != null) return;
        for (final variable in node.variables.variables) {
          if (_public(variable.name.lexeme, variable)) {
            reporter.atNode(variable, _code);
          }
        }
      });
    }
    // Detectar fields de clase sin type annotation
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      _checkFieldDeclaration(node, reporter);
    });

    // Detectar variables locales sin type annotation
    context.registry.addVariableDeclarationStatement((
      VariableDeclarationStatement node,
    ) {
      _checkVariableDeclarationStatement(node, reporter);
    });

    // Detectar loop variables sin type annotation
    context.registry.addForStatement((ForStatement node) {
      _checkForStatement(node, reporter);
    });

    context.registry.addForElement((ForElement node) {
      _checkForElement(node, reporter);
    });
  }

  bool _public(String name, AstNode node) {
    if (name.startsWith('_')) return false;
    final owner = node.thisOrAncestorOfType<ClassDeclaration>();
    return owner == null || !owner.name.lexeme.startsWith('_');
  }

  bool _publicSignature(AstNode node) {
    AstNode? owner = node.parent;
    while (owner != null) {
      if (owner is MethodDeclaration) return _public(owner.name.lexeme, owner);
      if (owner is ConstructorDeclaration) {
        return _public(owner.name?.lexeme ?? '', owner);
      }
      if (owner is FunctionExpression) {
        final declaration = owner.parent;
        return declaration is FunctionDeclaration &&
            declaration.parent is CompilationUnit &&
            _public(declaration.name.lexeme, declaration);
      }
      owner = owner.parent;
    }
    return false;
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
        if (policy == 'selective' && !_public(variable.name.lexeme, node)) {
          continue;
        }
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
        if (policy == 'selective' &&
            variable.declaredFragment?.element.type is! DynamicType &&
            !matchesAnyWildcard(variable.name.lexeme, localNames)) {
          continue;
        }
        reporter.atNode(variable, _code);
      }
    }
  }

  /// Checks if a for-statement loop variable has explicit type annotation.
  void _checkForStatement(ForStatement node, DiagnosticReporter reporter) {
    if (policy == 'selective') return;
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
  void _checkForElement(ForElement node, DiagnosticReporter reporter) {
    if (policy == 'selective') return;
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

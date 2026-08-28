import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces one public type per file for better code organization.
/// Only allows direct subclasses of the main class in the same file.
/// Prohibits independent enums, mixins, and unrelated classes.
class OneClassPerFileLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [OneClassPerFileLint].
  const OneClassPerFileLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Move this type to its own file. Only the main class and its direct subclasses should share a file for better organization.',
    name: 'one_class_per_file',
    problemMessage:
        'Multiple independent public types in one file violates the single responsibility principle. Each file should contain one primary type.',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      final publicTypes = <Declaration>[];

      // Collect all public type declarations (classes, enums, mixins)
      for (final declaration in node.declarations) {
        if (_isPublicTypeDeclaration(declaration)) {
          publicTypes.add(declaration);
        }
      }

      // Check if we have multiple public types
      if (publicTypes.length > 1) {
        _analyzeMultiplePublicTypes(publicTypes, reporter);
      }
    });
  }

  /// Checks if a declaration is a public type (class, enum, mixin).
  bool _isPublicTypeDeclaration(Declaration declaration) {
    if (declaration is ClassDeclaration) {
      return !declaration.name.lexeme.startsWith('_');
    }

    if (declaration is EnumDeclaration) {
      return !declaration.name.lexeme.startsWith('_');
    }

    if (declaration is MixinDeclaration) {
      return !declaration.name.lexeme.startsWith('_');
    }

    return false;
  }

  /// Analyzes multiple public types and reports violations.
  void _analyzeMultiplePublicTypes(
      List<Declaration> types, DiagnosticReporter reporter) {
    // Find the main class (largest class, or first class if no classes)
    ClassDeclaration? mainClass = _findMainClass(types);

    // If no main class found, all types are violations except the first
    if (mainClass == null) {
      for (int i = 1; i < types.length; i++) {
        reporter.atNode(types[i], _code);
      }
      return;
    }

    // Check each type against the main class
    for (final typeDecl in types) {
      if (typeDecl == mainClass) continue;

      // Only direct subclasses of main class are allowed
      if (!_isDirectSubclass(typeDecl, mainClass)) {
        reporter.atNode(typeDecl, _code);
      }
    }
  }

  /// Finds the main class among the types (largest class).
  ClassDeclaration? _findMainClass(List<Declaration> types) {
    ClassDeclaration? largest;
    int maxLines = 0;

    for (final type in types) {
      if (type is ClassDeclaration) {
        final lines = _getDeclarationLineCount(type);
        if (lines > maxLines) {
          maxLines = lines;
          largest = type;
        }
      }
    }

    // If no significant main class, return first class found
    if (largest == null) {
      for (final type in types) {
        if (type is ClassDeclaration) {
          return type;
        }
      }
    }

    return largest;
  }

  /// Gets the approximate line count for a declaration.
  int _getDeclarationLineCount(Declaration declaration) {
    try {
      final start = declaration.offset;
      final end = declaration.end;
      final sourceText = declaration.root.toSource();

      // Ensure offsets are within bounds
      if (start < 0 || end > sourceText.length || start > end) {
        return 1; // Default fallback
      }

      final content = sourceText.substring(start, end);
      return content.split('\n').length;
    } catch (e) {
      // Fallback to a simple heuristic
      return declaration.toString().split('\n').length;
    }
  }

  /// Checks if a type is a direct subclass of the main class.
  bool _isDirectSubclass(Declaration typeDecl, ClassDeclaration mainClass) {
    // Only classes can be subclasses
    if (typeDecl is! ClassDeclaration) return false;

    final extendsClause = typeDecl.extendsClause;
    if (extendsClause == null) return false;

    // Check if it directly extends the main class
    final superClassName = extendsClause.superclass.name.lexeme;
    return superClassName == mainClass.name.lexeme;
  }
}

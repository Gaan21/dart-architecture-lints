import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prohibits the use of the 'late' keyword except for
/// justified dependency injection cases.
class NoLateKeywordLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoLateKeywordLint].
  NoLateKeywordLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'no_late_keyword',
    'El keyword "late" debe evitarse excepto para dependency injection. Puede causar errores en runtime y hace la inicialización impredecible.',
    correctionMessage:
        'Usa nullable (Type?) o inicializa en constructor. "late" solo se permite para DI (GetIt, ServiceLocator, etc.).\n'
        'Ejemplo:\n'
        '  // ❌ late String name;\n'
        '  // ✅ String? name; o\n'
        '  // ✅ final String name = _init();\n'
        '  // ✅ late final GetIt locator; // OK para DI',
  );

  /// Executes the lint rule to detect inappropriate uses of the 'late' keyword.
  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    // Exclude test files
    final filePath = resolver.path;
    if (_isTestFile(filePath)) return;

    context.registry.addVariableDeclarationList((VariableDeclarationList node) {
      // Check if this variable declaration has the 'late' keyword
      if (node.lateKeyword != null) {
        // Check if this is a justified DI case
        if (!_isJustifiedDICase(node)) {
          reporter.atToken(node.lateKeyword!, _code);
        }
      }
    });
  }

  /// Checks if the file is a test file.
  bool _isTestFile(String filePath) {
    final segments = filePath.toLowerCase().split('/');
    return segments.any((segment) => segment.contains('test'));
  }

  /// Determines if the 'late' usage is justified for dependency injection.
  ///
  /// Justified cases include:
  /// - late final fields with DI-related type names (GetIt, Locator, etc.)
  /// - late final fields in classes that seem to be DI containers
  bool _isJustifiedDICase(VariableDeclarationList node) {
    // Must be 'late final' for DI justification
    if (node.keyword?.type != Keyword.FINAL) {
      return false;
    }

    // Check if the type suggests dependency injection
    final type = node.type;
    if (type != null) {
      final typeName = type.toString().toLowerCase();

      // Known DI framework types
      const diTypes = {
        'getit',
        'locator',
        'servicelocator',
        'container',
        'injector',
        'provider',
        'resolver',
      };

      // Check if type name contains DI-related keywords
      for (final diType in diTypes) {
        if (typeName.contains(diType)) {
          return true;
        }
      }
    }

    // Check if we're in a class that seems to be a DI container
    final classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDeclaration != null) {
      final className = classDeclaration.namePart.typeName.lexeme.toLowerCase();

      const diClassPatterns = {
        'container',
        'locator',
        'injector',
        'servicecontainer',
        'dependencycontainer',
        'di',
      };

      for (final pattern in diClassPatterns) {
        if (className.contains(pattern)) {
          return true;
        }
      }
    }

    return false;
  }
}

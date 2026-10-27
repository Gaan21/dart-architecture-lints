import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces UseCase pattern with public execute() method returning `Result<T>`.
/// Ensures consistency in Clean Architecture UseCase contracts.
class UseCasesFollowPatternLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [UseCasesFollowPatternLint].
  UseCasesFollowPatternLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'usecases_follow_pattern',
    'UseCase sin método execute() requerido. Los UseCases de Clean Architecture deben tener una interfaz consistente para ejecución.',
    correctionMessage:
        'Añade método execute() público que retorne Result<T> o Future<Result<T>>.\n'
        'Ejemplo:\n'
        '  @override\n'
        '  Future<Result<User>> execute(GetUserParams params) async {\n'
        '    return await repository.getUser(params.id);\n'
        '  }',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Only check classes that end with "UseCase"
      if (!_isUseCaseClass(node)) return;

      // Skip abstract classes - they don't need to implement execute()
      if (node.abstractKeyword != null) return;

      // Check if class has proper execute() method
      if (!_hasValidExecuteMethod(node)) {
        reporter.atNode(node, _code);
      }
    });
  }

  /// Checks if a class is a UseCase class (ends with "UseCase").
  bool _isUseCaseClass(ClassDeclaration classDecl) {
    return classDecl.namePart.typeName.lexeme.endsWith('UseCase');
  }

  /// Checks if the class has a valid public execute() method.
  bool _hasValidExecuteMethod(ClassDeclaration classDecl) {
    for (final member in classDecl.body.members) {
      if (member is MethodDeclaration) {
        // Check if it's a public execute method
        if (_isPublicExecuteMethod(member)) {
          // Check if return type is Result<T> or Future<Result<T>>
          return _hasValidReturnType(member);
        }
      }
    }
    return false;
  }

  /// Checks if a method is a public execute method.
  bool _isPublicExecuteMethod(MethodDeclaration method) {
    // Must be named "execute"
    if (method.name.lexeme != 'execute') return false;

    // Must be public (not starting with _)
    if (method.name.lexeme.startsWith('_')) return false;

    // Must not be getter or setter
    if (method.isGetter || method.isSetter) return false;

    return true;
  }

  /// Checks if the method has a valid return type (`Result<T>` or `Future<Result<T>>`).
  bool _hasValidReturnType(MethodDeclaration method) {
    final returnType = method.returnType;
    if (returnType == null) return false;

    final returnTypeName = _getTypeName(returnType);

    // Check for Result<T>
    if (returnTypeName.startsWith('Result<')) return true;

    // Check for Future<Result<T>>
    if (returnTypeName.startsWith('Future<Result<')) return true;

    return false;
  }

  /// Gets the type name as a string from a TypeAnnotation.
  String _getTypeName(TypeAnnotation typeAnnotation) {
    if (typeAnnotation is NamedType) {
      final name = typeAnnotation.name.lexeme;

      // Handle generic types
      final typeArgs = typeAnnotation.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final argNames = typeArgs.arguments
            .map((arg) => _getTypeName(arg))
            .join(', ');
        return '$name<$argNames>';
      }

      return name;
    }

    // Fallback for other type annotations
    return typeAnnotation.toString();
  }
}

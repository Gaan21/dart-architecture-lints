import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces methods to follow a specific order:
/// 1. Getters and setters
/// 2. Overridden methods (annotated with @override)
/// 3. Public methods
/// 4. Private methods
///
/// This rule helps maintain a consistent method organization in Dart classes, making
/// it easier for developers to understand the structure and purpose of each method.
/// By following this order, the overridden methods are grouped at the top, followed by
/// methods that are publicly accessible, and finally the private/internal methods.
class MethodOrderRule extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [MethodOrderRule].
  MethodOrderRule() : super(code: _code);

  /// The lint code associated with this rule.
  ///
  /// - **name**: Unique identifier for the lint rule.
  /// - **problemMessage**: Description of the problem when the order is incorrect.
  /// - **correctionMessage**: Suggestion to rearrange methods to adhere to the expected order.
  static const _code = LintCode(
    'method_order',
    'Methods are not in the correct order. Expected: getters/setters first, then @override methods, then public methods, then private methods.',
    correctionMessage: 'Move this method to maintain the order: getters/setters → @override methods → public methods → private methods. This improves code readability and consistency.',
  );

  /// The main entry point of the lint rule, which traverses Dart code to enforce
  /// the desired method order.
  ///
  /// The [resolver] is used to resolve the classes in the Dart file, and the [reporter]
  /// is used to log any lint violations. The [context] provides additional information
  /// about the custom lint environment.
  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration classDeclaration) {
      final List<MethodDeclaration> methodDeclarations = classDeclaration
          .body
          .members
          .whereType<MethodDeclaration>()
          .toList();

      _checkMethodOrder(methodDeclarations, reporter);
    });
  }

  /// Checks the order of methods within a class to ensure they follow the desired order.
  ///
  /// The [methodDeclarations] parameter contains the list of methods in the class.
  /// The [errorReporter] is used to report any violations found.
  void _checkMethodOrder(
    List<MethodDeclaration> methodDeclarations,
    DiagnosticReporter errorReporter,
  ) {
    bool foundOverrideMethod = false;
    bool foundPublicMethod = false;
    bool foundPrivateMethod = false;

    for (final MethodDeclaration method in methodDeclarations) {
      if (_isGetterOrSetter(method)) {
        // Getters/setters deben ir primero
        if (foundOverrideMethod || foundPublicMethod || foundPrivateMethod) {
          errorReporter.atNode(method, _code);
        }
      } else if (_isOverride(method)) {
        // @override va después de getters/setters
        if (foundPublicMethod || foundPrivateMethod) {
          errorReporter.atNode(method, _code);
        } else {
          foundOverrideMethod = true;
        }
      } else if (_isPublic(method)) {
        // Métodos públicos van después de @override
        if (foundPrivateMethod) {
          errorReporter.atNode(method, _code);
        } else {
          foundPublicMethod = true;
        }
      } else if (_isPrivate(method)) {
        // Métodos privados van al final
        foundPrivateMethod = true;
      }
    }
  }

  /// Determines if a given [methodDeclaration] is an overridden method.
  ///
  /// Returns `true` if the method is annotated with `@override`, otherwise `false`.
  bool _isOverride(MethodDeclaration methodDeclaration) {
    return methodDeclaration.metadata.any(
      (Annotation annotation) =>
          annotation.name.name == 'override' &&
          annotation.atSign.type.lexeme == '@',
    );
  }

  /// Determines if a given [methodDeclaration] is a public method.
  ///
  /// Returns `true` if the method is public (i.e., not private), otherwise `false`.
  bool _isPublic(MethodDeclaration methodDeclaration) {
    return !methodDeclaration.name.lexeme.startsWith('_');
  }

  /// Determines if a given [methodDeclaration] is a private method.
  ///
  /// Returns `true` if the method is private (i.e., its name starts with an underscore), otherwise `false`.
  bool _isPrivate(MethodDeclaration methodDeclaration) {
    return methodDeclaration.name.lexeme.startsWith('_');
  }

  /// Determines if a given [methodDeclaration] is a getter or setter.
  ///
  /// Returns `true` if the method is a getter or setter, otherwise `false`.
  bool _isGetterOrSetter(MethodDeclaration methodDeclaration) {
    return methodDeclaration.isGetter || methodDeclaration.isSetter;
  }
}

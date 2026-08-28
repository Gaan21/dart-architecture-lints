import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Lint rule that validates log context against the enclosing symbol scope.
///
/// Scope (v1):
/// - Only applies to `work_tracker/lib/**` files.
/// - Only checks `AppLoggerService.error(...)` and `.warning(...)`.
/// - Only checks when `context:` is present and is a simple string literal.
/// - Only checks when a reliable enclosing member scope can be inferred.
class LoggerContextMatchesScopeLint extends GeneratedSkippingDartLintRule {
  const LoggerContextMatchesScopeLint() : super(code: _code);

  static const _code = LintCode(
    name: 'logger_context_matches_scope',
    problemMessage:
        'El context del log no coincide con el scope real del símbolo envolvente.',
    correctionMessage:
        'Usa context con formato "TypeName.memberCanonical", donde memberCanonical '
        'elimina prefijo "_" y sufijo "Internal" del nombre real del miembro.',
  );

  static const _methodsToCheck = {'error', 'warning'};

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!_isWorkTrackerLibFile(resolver.path)) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      _checkMethodInvocation(node, reporter);
    });
  }

  void _checkMethodInvocation(
    MethodInvocation node,
    DiagnosticReporter reporter,
  ) {
    final methodName = node.methodName.name;
    if (!_methodsToCheck.contains(methodName)) return;
    if (!_isAppLoggerServiceCall(node)) return;

    final contextExpression = _findContextArgument(node.argumentList);
    if (contextExpression == null) return;
    if (contextExpression is! SimpleStringLiteral) return;

    final actualContext = contextExpression.stringValue;
    if (actualContext == null) return;

    final expectedContext = _deriveExpectedContext(node);
    if (expectedContext == null) return;

    if (actualContext == expectedContext) return;

    reporter.atNode(
      contextExpression,
      LintCode(
        name: 'logger_context_matches_scope',
        problemMessage:
            'Context no coincide con el scope real: expected "$expectedContext", '
            'actual "$actualContext".',
        correctionMessage:
            'Actualiza context al scope canónico del símbolo envolvente: '
            '"$expectedContext".',
      ),
    );
  }

  bool _isWorkTrackerLibFile(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    return normalized.contains('/work_tracker/lib/');
  }

  bool _isAppLoggerServiceCall(MethodInvocation node) {
    final target = node.target;
    if (target == null) return false;

    if (target is SimpleIdentifier && _isLoggerServiceName(target.name)) {
      return true;
    }

    if (target is PrefixedIdentifier &&
        _isLoggerServiceName(target.identifier.name)) {
      return true;
    }

    final staticType = target.staticType;
    if (staticType != null &&
        _isLoggerServiceName(staticType.getDisplayString())) {
      return true;
    }

    return false;
  }

  bool _isLoggerServiceName(String name) {
    return name == 'AppLoggerService' ||
        name == 'appLoggerService' ||
        name.endsWith('LoggerService');
  }

  Expression? _findContextArgument(ArgumentList args) {
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'context') {
        return arg.expression;
      }
    }
    return null;
  }

  String? _deriveExpectedContext(AstNode node) {
    AstNode? current = node;

    while (current != null) {
      if (current is MethodDeclaration) {
        final typeName = _findEnclosingTypeName(current);
        if (typeName == null) return null;

        final memberName = current.name.lexeme;
        return '$typeName.${_canonicalizeMemberName(memberName)}';
      }

      if (current is ConstructorDeclaration) {
        final typeName = _findEnclosingTypeName(current);
        if (typeName == null) return null;

        final constructorName = current.name?.lexeme;
        if (constructorName == null || constructorName.isEmpty) {
          // v1: unnamed constructors are skipped to avoid non-obvious contexts.
          return null;
        }

        return '$typeName.${_canonicalizeMemberName(constructorName)}';
      }

      current = current.parent;
    }

    return null;
  }

  String? _findEnclosingTypeName(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      if (current is ClassDeclaration) return current.name.lexeme;
      if (current is MixinDeclaration) return current.name.lexeme;
      if (current is EnumDeclaration) return current.name.lexeme;
      if (current is ExtensionDeclaration) return current.name?.lexeme;

      current = current.parent;
    }

    return null;
  }

  String _canonicalizeMemberName(String rawName) {
    var name = rawName;

    if (name.startsWith('_')) {
      name = name.substring(1);
    }

    if (name.endsWith('Internal')) {
      name = name.substring(0, name.length - 'Internal'.length);
    }

    return name;
  }
}

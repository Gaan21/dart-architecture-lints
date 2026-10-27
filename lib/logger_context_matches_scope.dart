import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

import 'timezone_safety_utils.dart';

/// Lint rule that validates log context against the enclosing symbol scope.
///
/// Defaults: files matching `**/lib/**`; `error`/`warning` calls on receivers
/// named `AppLoggerService`, `appLoggerService` or `*LoggerService`. Only literal
/// `context:` values with a reliable enclosing member scope are checked.
class LoggerContextMatchesScopeLint extends GeneratedSkippingDartLintRule {
  LoggerContextMatchesScopeLint({
    this.includeGlobs = defaultIncludeGlobs,
    this.excludeGlobs = const [],
    this.loggerNames,
    this.methods = const ['error', 'warning'],
    this.contextArgument = 'context',
  }) : super(code: _code);

  /// Generic default scope: every library file of the analyzed package.
  static const defaultIncludeGlobs = ['**/lib/**'];

  final List<String>? loggerNames;
  final List<String> includeGlobs, excludeGlobs, methods;
  final String contextArgument;

  static const _code = LintCode(
    'logger_context_matches_scope',
    'El context del log no coincide con el scope real del símbolo envolvente.',
    correctionMessage:
        'Usa context con formato "TypeName.memberCanonical", donde memberCanonical '
        'elimina prefijo "_" y sufijo "Internal" del nombre real del miembro.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    if (matchesAnyGlob(resolver.path, excludeGlobs)) return;
    if (!matchesAnyGlob(resolver.path, includeGlobs)) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      _checkMethodInvocation(node, reporter);
    });
  }

  void _checkMethodInvocation(
    MethodInvocation node,
    DiagnosticReporter reporter,
  ) {
    final methodName = node.methodName.name;
    if (!methods.contains(methodName)) return;
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
        'logger_context_matches_scope',
        'Context no coincide con el scope real: expected "$expectedContext", '
            'actual "$actualContext".',
        correctionMessage:
            'Actualiza context al scope canónico del símbolo envolvente: '
            '"$expectedContext".',
      ),
    );
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
    if (loggerNames != null) return matchesAnyWildcard(name, loggerNames!);
    return name == 'AppLoggerService' ||
        name == 'appLoggerService' ||
        name.endsWith('LoggerService');
  }

  Expression? _findContextArgument(ArgumentList args) {
    for (final arg in args.arguments) {
      if (arg is NamedArgument && arg.name.lexeme == contextArgument) {
        return arg.argumentExpression;
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
      if (current is ClassDeclaration) return current.namePart.typeName.lexeme;
      if (current is MixinDeclaration) return current.name.lexeme;
      if (current is EnumDeclaration) return current.namePart.typeName.lexeme;
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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that discourages direct use of DateTime constructors that create local time.
/// Enforces UTC-first approach and dependency injection for testability.
class NoDateTimeNowLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoDateTimeNowLint].
  const NoDateTimeNowLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    name: 'no_local_datetime_constructors',
    problemMessage:
        'DateTime constructor creates local time which causes timezone inconsistencies. Use UTC constructors or inject Clock for testability.',
    correctionMessage:
        'Use DateTime.utc(), DateTime.parse() with Z suffix, DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true), or inject Clock dependency for current time.',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check InstanceCreationExpression for problematic DateTime constructors
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      _checkDateTimeConstructor(node, reporter);
    });

    // Check MethodInvocation for DateTime.parse() and DateTime.now()
    context.registry.addMethodInvocation((MethodInvocation node) {
      _checkDateTimeMethod(node, reporter);
    });
  }

  /// Checks DateTime constructors for local time creation.
  void _checkDateTimeConstructor(
      InstanceCreationExpression node, DiagnosticReporter reporter) {
    if (!_isDateTimeConstructor(node)) return;

    final constructorName = node.constructorName.name?.name;

    // DateTime.now() -> report
    if (constructorName == 'now') {
      reporter.atNode(node, _code);
      return;
    }

    // DateTime.utc() -> allow
    if (constructorName == 'utc') return;

    // DateTime.fromMillisecondsSinceEpoch() without isUtc: true -> report
    if (constructorName == 'fromMillisecondsSinceEpoch' &&
        !_hasIsUtcTrue(node)) {
      reporter.atNode(node, _code);
      return;
    }

    // DateTime.fromMicrosecondsSinceEpoch() without isUtc: true -> report
    if (constructorName == 'fromMicrosecondsSinceEpoch' &&
        !_hasIsUtcTrue(node)) {
      reporter.atNode(node, _code);
      return;
    }

    // Regular DateTime() constructor -> report
    if (constructorName == null) {
      reporter.atNode(node, _code);
    }
  }

  /// Checks DateTime static methods for local time creation.
  void _checkDateTimeMethod(MethodInvocation node, DiagnosticReporter reporter) {
    final target = node.target;
    if (target is! Identifier || target.name != 'DateTime') return;

    final methodName = node.methodName.name;

    // DateTime.now() -> report
    if (methodName == 'now') {
      reporter.atNode(node, _code);
      return;
    }

    // DateTime.parse() without UTC suffix or .toUtc() -> report
    if (methodName == 'parse' && !_hasUtcHandling(node)) {
      reporter.atNode(node, _code);
    }
  }

  /// Checks if instance creation is DateTime constructor.
  bool _isDateTimeConstructor(InstanceCreationExpression node) {
    final type = node.constructorName.type;
    return type.name.lexeme == 'DateTime';
  }

  /// Checks if DateTime.fromMillisecondsSinceEpoch has isUtc: true.
  bool _hasIsUtcTrue(InstanceCreationExpression node) {
    final arguments = node.argumentList.arguments;

    for (final argument in arguments) {
      if (argument is NamedExpression && argument.name.label.name == 'isUtc') {
        final expression = argument.expression;
        if (expression is BooleanLiteral && expression.value) {
          return true;
        }
      }
    }

    return false;
  }

  /// Checks if DateTime.parse() has UTC handling.
  bool _hasUtcHandling(MethodInvocation node) {
    // Check if string argument ends with 'Z' (UTC indicator)
    final arguments = node.argumentList.arguments;
    if (arguments.isNotEmpty) {
      final firstArg = arguments.first;
      if (firstArg is StringLiteral) {
        final value = firstArg.stringValue;
        if (value != null && value.endsWith('Z')) {
          return true;
        }
      }
    }

    // Check if followed by .toUtc()
    AstNode? parent = node.parent;
    while (parent != null) {
      if (parent is MethodInvocation && parent.methodName.name == 'toUtc') {
        return true;
      }
      if (parent is! PropertyAccess && parent is! MethodInvocation) break;
      parent = parent.parent;
    }

    return false;
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

import 'time_scope.dart';

/// A lint rule that discourages direct use of DateTime constructors that create local time.
/// Enforces UTC-first approach and dependency injection for testability.
class NoDateTimeNowLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoDateTimeNowLint].
  NoDateTimeNowLint({this.scope = const TimeScope()}) : super(code: _code);
  final TimeScope scope;

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'no_local_datetime_constructors',
    'DateTime constructor creates local time which causes timezone inconsistencies. Use UTC constructors or inject Clock for testability.',
    correctionMessage: 'Use DateTime.utc(), DateTime.parse() with Z suffix, DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true), or inject Clock dependency for current time.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    if (!scope.includes(resolver.path)) return;
    // Check InstanceCreationExpression for problematic DateTime constructors
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final name = node.constructorName.name?.name;
      if (name == 'now' && scope.clock(resolver.path)) return;
      if (name == null && scope.civil(resolver.path)) return;
      _checkDateTimeConstructor(node, reporter);
    });

    // Check MethodInvocation for DateTime.parse() and DateTime.now()
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'now' && scope.clock(resolver.path)) return;
      _checkDateTimeMethod(node, reporter);
    });
  }

  /// Checks DateTime constructors for local time creation.
  void _checkDateTimeConstructor(
    InstanceCreationExpression node,
    DiagnosticReporter reporter,
  ) {
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
  void _checkDateTimeMethod(
    MethodInvocation node,
    DiagnosticReporter reporter,
  ) {
    final element = node.methodName.element;
    if (element?.enclosingElement?.name != 'DateTime' ||
        element?.library?.uri.toString() != 'dart:core') {
      return;
    }

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
    final element = node.constructorName.type.type?.element;
    return element?.name == 'DateTime' &&
        element?.library?.uri.toString() == 'dart:core';
  }

  /// Checks if DateTime.fromMillisecondsSinceEpoch has isUtc: true.
  bool _hasIsUtcTrue(InstanceCreationExpression node) {
    final arguments = node.argumentList.arguments;

    for (final argument in arguments) {
      if (argument is NamedArgument && argument.name.lexeme == 'isUtc') {
        final expression = argument.argumentExpression;
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
        if (value != null &&
            RegExp(r'[Tt ].*(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$').hasMatch(value)) {
          return true;
        }
      }
    }

    // Check if followed by .toUtc()
    final parent = node.parent;
    return parent is MethodInvocation &&
        identical(parent.target, node) &&
        parent.methodName.name == 'toUtc';
  }
}

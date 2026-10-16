import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'generated_skipping_dart_lint_rule.dart';
import 'time_scope.dart';
import 'timezone_safety_utils.dart';

/// Requires UTC representations of instants at data-layer construction sites.
class EnforceUtcDatesLint extends GeneratedSkippingDartLintRule {
  const EnforceUtcDatesLint({this.scope = const TimeScope()})
    : super(code: _code);
  final TimeScope scope;

  static EnforceUtcDatesLint fromConfigs(CustomLintConfigs configs) =>
      EnforceUtcDatesLint(
        scope: TimeScope.fromJson(readRuleOptions(configs, _code.name)),
      );

  static const _code = LintCode(
    name: 'enforce_utc_dates',
    problemMessage: 'Represent data-layer instants in UTC.',
    correctionMessage:
        'Use UTC construction or convert this instant with toUtc(). '
        'Model civil calendar values separately in explicitly scoped files.',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!scope.includes(resolver.path)) return;
    const layers = {
      'data',
      'datasource',
      'datasources',
      'repository',
      'repositories',
      'infrastructure',
      'models',
      'entities',
    };
    if (!normalizeLintPath(resolver.path).split('/').any(layers.contains)) {
      return;
    }

    context.registry.addInstanceCreationExpression((node) {
      final type = node.constructorName.type.type;
      if (type?.element?.name != 'DateTime' ||
          type?.element?.library?.uri.toString() != 'dart:core') {
        return;
      }
      final name = node.constructorName.name?.name;
      if (name == 'utc' || _converted(node)) return;
      if (name == null && scope.civil(resolver.path)) return;
      if (name == 'now' && scope.clock(resolver.path)) return;
      if ((name == 'fromMillisecondsSinceEpoch' ||
              name == 'fromMicrosecondsSinceEpoch') &&
          node.argumentList.arguments.whereType<NamedExpression>().any(
            (argument) =>
                argument.name.label.name == 'isUtc' &&
                argument.expression is BooleanLiteral &&
                (argument.expression as BooleanLiteral).value,
          )) {
        return;
      }
      reporter.atNode(node, _code);
    });
    context.registry.addMethodInvocation((node) {
      // Resolved static return type avoids matching unrelated parse methods.
      if (node.methodName.name != 'parse' ||
          node.staticType?.element?.name != 'DateTime' ||
          node.methodName.element?.enclosingElement?.name != 'DateTime' ||
          node.methodName.element?.library?.uri.toString() != 'dart:core') {
        return;
      }
      if (_converted(node)) return;
      final argument = node.argumentList.arguments.firstOrNull;
      if (argument is StringLiteral) {
        final value = argument.stringValue;
        // Dart normalizes explicitly offset ISO timestamps to UTC.
        if (value != null &&
            RegExp(r'[Tt ].*(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$').hasMatch(value)) {
          return;
        }
      }
      reporter.atNode(node, _code);
    });
    // Epoch counts represent the same instant regardless of the display zone.
  }

  bool _converted(Expression node) {
    final parent = node.parent;
    return parent is MethodInvocation &&
        identical(parent.target, node) &&
        parent.methodName.name == 'toUtc';
  }
}

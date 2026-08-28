import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces UTC dates for persistence and data layer.
/// Prevents timezone issues in offline-first applications.
class EnforceUtcDatesLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [EnforceUtcDatesLint].
  const EnforceUtcDatesLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Convert to UTC using .toUtc() or use DateTime.utc() constructor. For parsing, ensure the result is converted to UTC before persistence.',
    name: 'enforce_utc_dates',
    problemMessage:
        'DateTime in data layer is not in UTC timezone. This can cause inconsistent behavior across different timezones and devices.',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Only apply to data/persistence layer files
    if (!_isDataLayerFile(filePath)) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      _checkDateTimeUsage(node, reporter);
    });

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      _checkDateTimeConstructor(node, reporter);
    });

    context.registry.addPropertyAccess((PropertyAccess node) {
      _checkDateTimeProperty(node, reporter);
    });
  }

  /// Checks if the file is in data/persistence layer.
  bool _isDataLayerFile(String filePath) {
    final segments = filePath.split('/');

    // Check for data layer indicators
    final dataLayerIndicators = [
      'data',
      'datasource',
      'datasources',
      'repository',
      'repositories',
      'infrastructure',
      'models',
      'entities', // Domain entities with serialization
    ];

    return dataLayerIndicators.any((indicator) => segments.contains(indicator));
  }

  /// Checks DateTime method invocations for missing UTC conversion.
  void _checkDateTimeUsage(MethodInvocation node, DiagnosticReporter reporter) {
    // Check DateTime.now() without .toUtc()
    if (_isDateTimeNow(node) && !_isAlreadyUtc(node)) {
      reporter.atNode(node, _code);
      return;
    }

    // Check DateTime.parse() without UTC handling
    if (_isDateTimeParse(node) && !_hasUtcParameter(node)) {
      reporter.atNode(node, _code);
      return;
    }

    // Check .millisecondsSinceEpoch without prior .toUtc()
    if (_isMillisecondsProperty(node) && !_isFromUtcSource(node)) {
      reporter.atNode(node, _code);
      return;
    }
  }

  /// Checks DateTime constructors for UTC usage.
  void _checkDateTimeConstructor(
      InstanceCreationExpression node, DiagnosticReporter reporter) {
    if (!_isDateTimeConstructor(node)) return;

    // Skip if using DateTime.utc constructor
    final constructorName = node.constructorName.name?.name;
    if (constructorName == 'utc') return;

    // Skip if fromMillisecondsSinceEpoch with isUtc: true
    if (constructorName == 'fromMillisecondsSinceEpoch' &&
        _hasIsUtcTrue(node)) {
      return;
    }

    // Regular DateTime constructor in data layer should be avoided
    if (constructorName == null) {
      reporter.atNode(node, _code);
    }
  }

  /// Checks DateTime property access that might need UTC conversion.
  void _checkDateTimeProperty(
      PropertyAccess node, DiagnosticReporter reporter) {
    // Check .millisecondsSinceEpoch on non-UTC DateTime
    if (node.propertyName.name == 'millisecondsSinceEpoch') {
      if (!_isFromUtcSource(node.target)) {
        reporter.atNode(node, _code);
      }
    }
  }

  /// Checks if method invocation is DateTime.now().
  bool _isDateTimeNow(MethodInvocation node) {
    if (node.methodName.name != 'now') return false;

    final target = node.target;
    if (target is Identifier && target.name == 'DateTime') return true;

    return false;
  }

  /// Checks if method invocation is DateTime.parse().
  bool _isDateTimeParse(MethodInvocation node) {
    if (node.methodName.name != 'parse') return false;

    final target = node.target;
    if (target is Identifier && target.name == 'DateTime') return true;

    return false;
  }

  /// Checks if the node represents millisecondsSinceEpoch property.
  bool _isMillisecondsProperty(MethodInvocation node) {
    // This is handled in PropertyAccess, not MethodInvocation
    return false;
  }

  /// Checks if DateTime is already UTC (has .toUtc() chain).
  bool _isAlreadyUtc(MethodInvocation node) {
    // Look for parent method invocation that calls .toUtc()
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

  /// Checks if DateTime.parse has UTC parameter or handling.
  bool _hasUtcParameter(MethodInvocation node) {
    // DateTime.parse doesn't have UTC parameter, but we can check if
    // it's followed by .toUtc()
    return _isAlreadyUtc(node);
  }

  /// Checks if the DateTime source is already UTC.
  bool _isFromUtcSource(Expression? expression) {
    if (expression == null) return false;

    // Check if it's a method chain ending in .toUtc()
    if (expression is MethodInvocation) {
      if (expression.methodName.name == 'toUtc') return true;
      return _isFromUtcSource(expression.target);
    }

    // Check if it's DateTime.utc() constructor
    if (expression is InstanceCreationExpression) {
      final constructorName = expression.constructorName.name?.name;
      return constructorName == 'utc';
    }

    return false;
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
}


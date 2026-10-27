import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Lint rule that enforces structured context in logging calls.
///
/// All logging calls via AppLoggerService must include a `context` parameter
/// with a deterministic, structured value following the pattern:
/// `Class.method` or `module.submodule.action`.
///
/// Rejects: empty, generic (`test`, `debug`, `tmp`), or non-deterministic values.
class LoggerContextMustBeStructuredLint extends GeneratedSkippingDartLintRule {
  LoggerContextMustBeStructuredLint() : super(code: _code);

  static const _code = LintCode(
    'logger_context_must_be_structured',
    'Llamada a AppLoggerService sin context estructurado válido. '
        'Un context inconsistente rompe la trazabilidad y agrupación de logs, '
        'dificultando el diagnóstico en producción.',
    correctionMessage:
        'Usa un context con formato "Class.method" o "module.submodule.action". '
        'Ejemplo: context: "UserRepository.fetchById" o '
        'context: "sync.pull.mergeConflict". '
        'Evita valores vacíos, genéricos (test, debug, tmp) o dinámicos.',
  );

  /// Logger methods that require structured context.
  /// Only error/warning/critical need mandatory context for production
  /// observability. debug/info are development-local and don't justify
  /// the ceremony.
  static const _logMethods = {'warning', 'error', 'critical'};

  /// Generic/prohibited context values.
  static const _prohibitedContexts = {
    'test',
    'debug',
    'tmp',
    'temp',
    'todo',
    'fixme',
    'hack',
    'xxx',
  };

  /// Pattern for valid structured context: Word.Word or word.word.word
  /// Examples: UserRepository.fetchById, sync.pull.mergeConflict
  static final _validContextPattern = RegExp(
    r'^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final filePath = resolver.path;
    final normalized = filePath.replaceAll('\\', '/');

    // Only apply to lib/
    if (!normalized.contains('/lib/')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      _checkMethodInvocation(node, reporter);
    });
  }

  void _checkMethodInvocation(
    MethodInvocation node,
    DiagnosticReporter reporter,
  ) {
    final methodName = node.methodName.name;
    if (!_logMethods.contains(methodName)) return;

    // Check if target is AppLoggerService
    if (!_isAppLoggerServiceCall(node)) return;

    // Find the 'context' named parameter
    final contextArg = _findContextArgument(node.argumentList);

    if (contextArg == null) {
      // No context parameter at all
      reporter.atNode(
        node,
        LintCode(
          'logger_context_must_be_structured',
          'Llamada a AppLoggerService.$methodName() sin parámetro context. '
              'Sin context, el log pierde trazabilidad: no se puede agrupar ni '
              'filtrar por origen en dashboards de observabilidad.',
          correctionMessage:
              'Añade el parámetro context con formato "Class.method". '
              'Ejemplo: AppLoggerService.$methodName("mensaje", '
              'context: "MyClass.myMethod")',
        ),
      );
      return;
    }

    // Validate the context value
    _validateContextValue(contextArg, methodName, reporter);
  }

  void _validateContextValue(
    Expression contextExpr,
    String methodName,
    DiagnosticReporter reporter,
  ) {
    // Only validate string literals; skip variables/expressions
    // (we can't statically evaluate runtime expressions)
    if (contextExpr is! StringLiteral) return;

    final value = contextExpr.stringValue;
    if (value == null) return;

    final trimmed = value.trim();

    // Check empty
    if (trimmed.isEmpty) {
      reporter.atNode(
        contextExpr,
        LintCode(
          'logger_context_must_be_structured',
          'Context vacío en AppLoggerService.$methodName(). '
              'Un context vacío imposibilita el filtrado y agrupación de logs.',
          correctionMessage:
              'Usa un context descriptivo: "Class.method" o "module.action". '
              'Ejemplo: context: "OrderRepository.create"',
        ),
      );
      return;
    }

    // Check prohibited generic values
    if (_prohibitedContexts.contains(trimmed.toLowerCase())) {
      reporter.atNode(
        contextExpr,
        LintCode(
          'logger_context_must_be_structured',
          'Context genérico "$trimmed" en AppLoggerService.$methodName(). '
              'Los valores genéricos (test, debug, tmp) no aportan trazabilidad '
              'y contaminan los filtros de observabilidad.',
          correctionMessage:
              'Reemplaza "$trimmed" por un context estructurado: '
              '"Class.method" o "module.submodule.action". '
              'Ejemplo: context: "AuthService.validateToken"',
        ),
      );
      return;
    }

    // Check structured format
    if (!_validContextPattern.hasMatch(trimmed)) {
      reporter.atNode(
        contextExpr,
        LintCode(
          'logger_context_must_be_structured',
          'Context "$trimmed" no sigue el formato estructurado requerido '
              'en AppLoggerService.$methodName(). '
              'El formato esperado es "Class.method" o "module.submodule.action" '
              'para garantizar consistencia en la agrupación de logs.',
          correctionMessage:
              'Usa formato dot-notation: "Class.method" o "module.action". '
              'Ejemplos válidos: "UserRepo.fetchAll", "sync.push.retry", '
              '"auth.token.refresh"',
        ),
      );
    }
  }

  bool _isAppLoggerServiceCall(MethodInvocation node) {
    final target = node.target;
    if (target == null) return false;

    // Direct static: AppLoggerService.info(...)
    if (target is SimpleIdentifier && _isLoggerServiceName(target.name)) {
      return true;
    }

    // Prefixed: prefix.AppLoggerService.info(...)
    if (target is PrefixedIdentifier &&
        _isLoggerServiceName(target.identifier.name)) {
      return true;
    }

    // Instance variable type check
    final staticType = target.staticType;
    if (staticType != null) {
      final typeName = staticType.getDisplayString();
      if (_isLoggerServiceName(typeName)) {
        return true;
      }
    }

    return false;
  }

  bool _isLoggerServiceName(String name) {
    return name == 'AppLoggerService' ||
        name == 'appLoggerService' ||
        name.endsWith('LoggerService');
  }

  /// Finds the `context` named argument in the argument list.
  Expression? _findContextArgument(ArgumentList args) {
    for (final arg in args.arguments) {
      if (arg is NamedArgument && arg.name.lexeme == 'context') {
        return arg.argumentExpression;
      }
    }
    return null;
  }
}

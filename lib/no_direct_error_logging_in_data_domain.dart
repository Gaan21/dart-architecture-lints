import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Lint rule that prevents direct error/warning logging in data and domain layers.
///
/// In Clean Architecture with Guard pattern, errors thrown in data/domain are
/// centralized through GuardMixin/BaseUseCase via ErrorReporter. Direct
/// `AppLoggerService.error(...)` or `.warning(...)` calls in these layers cause
/// double-logging and noise.
class NoDirectErrorLoggingInDataDomainLint
    extends GeneratedSkippingDartLintRule {
  const NoDirectErrorLoggingInDataDomainLint() : super(code: _code);

  static const _code = LintCode(
    name: 'no_direct_error_logging_in_data_domain',
    problemMessage:
        'Llamada directa a AppLoggerService.error/warning en capa data/domain. '
        'Los errores ya se centralizan en Guard/ErrorReporter; este log duplica '
        'la señal y genera ruido en observabilidad.',
    correctionMessage:
        'Elimina esta llamada y devuelve Failure(...) para que el error se '
        'propague al Guard/ErrorReporter. Si es una excepción técnica válida '
        'que necesita logging local, documenta la razón y solicita aprobación '
        'para añadirla al allowlist.',
  );

  /// Files explicitly allowed to use error/warning logging.
  static const _allowlistSuffixes = [
    'core/mixins/guard_mixin.dart',
    'domain/useCases/base_use_case.dart',
    'core/services/error_reporter_service.dart',
    'core/services/app_logger_service.dart',
  ];

  /// Logging methods that are prohibited in data/domain.
  static const _prohibitedMethods = {'error', 'warning'};

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Only apply to data/ and domain/ directories
    if (!_isDataOrDomainFile(filePath)) return;

    // Skip allowlisted files
    if (_isAllowlisted(filePath)) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      _checkMethodInvocation(node, reporter);
    });

    // Also detect prefixed identifier access: e.g. AppLoggerService.error
    context.registry.addFunctionExpressionInvocation(
      (FunctionExpressionInvocation node) {
        _checkFunctionExpressionInvocation(node, reporter);
      },
    );
  }

  void _checkMethodInvocation(
    MethodInvocation node,
    DiagnosticReporter reporter,
  ) {
    final methodName = node.methodName.name;
    if (!_prohibitedMethods.contains(methodName)) return;

    // Check if target is AppLoggerService (or a variable of that type)
    final target = node.target;
    if (target == null) return;

    if (_isAppLoggerServiceAccess(target, methodName)) {
      final level = methodName == 'error' ? 'error' : 'warning';
      reporter.atNode(
        node,
        LintCode(
          name: 'no_direct_error_logging_in_data_domain',
          problemMessage:
              'Llamada directa a AppLoggerService.$level() en capa data/domain. '
              'Los errores ya se centralizan en Guard/ErrorReporter (ver '
              '06_LOGGING_GOVERNANCE.md §1); este log duplica la señal y genera '
              'ruido en observabilidad.',
          correctionMessage:
              'Elimina esta llamada y devuelve Failure(...) para que el error '
              'se propague al Guard/ErrorReporter. '
              'Ejemplo: return Result.failure(AppException.unexpected(e)); '
              'Si es una excepción técnica válida (ej: fallback silencioso), '
              'documenta la razón y solicita aprobación para el allowlist.',
        ),
      );
    }
  }

  void _checkFunctionExpressionInvocation(
    FunctionExpressionInvocation node,
    DiagnosticReporter reporter,
  ) {
    // Handles cases like: AppLoggerService.error(...)
    // where the function expression is a property access
    final function = node.function;
    if (function is! PropertyAccess) return;

    final propertyName = function.propertyName.name;
    if (!_prohibitedMethods.contains(propertyName)) return;

    final target = function.target;
    if (target is Identifier && _isLoggerServiceName(target.name)) {
      final level = propertyName == 'error' ? 'error' : 'warning';
      reporter.atNode(
        node,
        LintCode(
          name: 'no_direct_error_logging_in_data_domain',
          problemMessage:
              'Llamada directa a AppLoggerService.$level() en capa data/domain. '
              'Los errores ya se centralizan en Guard/ErrorReporter (ver '
              '06_LOGGING_GOVERNANCE.md §1); este log duplica la señal y genera '
              'ruido en observabilidad.',
          correctionMessage:
              'Elimina esta llamada y devuelve Failure(...) para que el error '
              'se propague al Guard/ErrorReporter. '
              'Ejemplo: return Result.failure(AppException.unexpected(e)); '
              'Si es una excepción técnica válida (ej: fallback silencioso), '
              'documenta la razón y solicita aprobación para el allowlist.',
        ),
      );
    }
  }

  /// Checks whether the target of a method call refers to AppLoggerService.
  bool _isAppLoggerServiceAccess(Expression target, String methodName) {
    // Direct static call: AppLoggerService.error(...)
    if (target is SimpleIdentifier && _isLoggerServiceName(target.name)) {
      return true;
    }

    // Prefixed: prefix.AppLoggerService.error(...)
    if (target is PrefixedIdentifier &&
        _isLoggerServiceName(target.identifier.name)) {
      return true;
    }

    // Instance variable: _logger.error(...) where _logger is AppLoggerService
    // Check the static type of the target
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

  bool _isDataOrDomainFile(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    return normalized.contains('/data/') || normalized.contains('/domain/');
  }

  bool _isAllowlisted(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    return _allowlistSuffixes
        .any((suffix) => normalized.endsWith(suffix.replaceAll('\\', '/')));
  }
}

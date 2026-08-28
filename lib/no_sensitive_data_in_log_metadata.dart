import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Lint rule that prevents sensitive data from being logged.
///
/// Detects:
/// 1. Sensitive keys in metadata maps passed to logging calls.
/// 2. Sensitive keywords in string literal log messages.
///
/// Prohibited keys: token, password, authorization, cookie, secret,
/// apiKey, refreshToken, accessToken.
class NoSensitiveDataInLogMetadataLint extends GeneratedSkippingDartLintRule {
  const NoSensitiveDataInLogMetadataLint() : super(code: _code);

  static const _code = LintCode(
    name: 'no_sensitive_data_in_log_metadata',
    problemMessage:
        'Dato sensible detectado en logging. Loguear tokens, passwords o '
        'credenciales es un riesgo de seguridad y compliance (OWASP A09, GDPR). '
        'Los logs pueden persistir en texto plano en sistemas de observabilidad.',
    correctionMessage:
        'Elimina el dato sensible del log. Si necesitas trazabilidad, usa un '
        'identificador no sensible (ej: userId, requestId) o aplica masking '
        '(ej: "tok_***${'{'}token.substring(token.length - 4)}"). '
        'Nunca loguees tokens, passwords ni claves API completas.',
  );

  /// Sensitive key names (case-insensitive matching).
  static const _sensitiveKeys = {
    'token',
    'password',
    'authorization',
    'cookie',
    'secret',
    'apikey',
    'refreshtoken',
    'accesstoken',
    'passwd',
    'credentials',
    'bearer',
  };

  /// Sensitive patterns in string literals.
  static final _sensitiveStringPatterns = [
    RegExp(r'password\s*[:=]', caseSensitive: false),
    RegExp(r'token\s*[:=]', caseSensitive: false),
    RegExp(r'Bearer\s+\S+', caseSensitive: false),
    RegExp(r'api[_-]?key\s*[:=]', caseSensitive: false),
    RegExp(r'secret\s*[:=]', caseSensitive: false),
    RegExp(r'authorization\s*[:=]', caseSensitive: false),
  ];

  /// Logger methods to check.
  static const _logMethods = {
    'debug',
    'info',
    'warning',
    'error',
    'critical',
  };

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
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

    // Check metadata parameter for sensitive keys
    _checkMetadataArgument(node.argumentList, methodName, reporter);

    // Check message string literals for sensitive patterns
    _checkMessageArguments(node.argumentList, methodName, reporter);
  }

  /// Checks the `metadata` named parameter for sensitive keys.
  void _checkMetadataArgument(
    ArgumentList args,
    String methodName,
    DiagnosticReporter reporter,
  ) {
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'metadata') {
        final expr = arg.expression;
        if (expr is SetOrMapLiteral) {
          _checkMapLiteral(expr, methodName, reporter);
        }
        break;
      }
    }
  }

  void _checkMapLiteral(
    SetOrMapLiteral mapLiteral,
    String methodName,
    DiagnosticReporter reporter,
  ) {
    for (final element in mapLiteral.elements) {
      if (element is MapLiteralEntry) {
        final key = element.key;
        String? keyName;

        if (key is StringLiteral) {
          keyName = key.stringValue;
        } else if (key is SimpleIdentifier) {
          keyName = key.name;
        }

        if (keyName != null && _isSensitiveKey(keyName)) {
          reporter.atNode(
            element,
            LintCode(
              name: 'no_sensitive_data_in_log_metadata',
              problemMessage: 'Clave sensible "$keyName" en metadata de '
                  'AppLoggerService.$methodName(). '
                  'Loguear "$keyName" es un riesgo de seguridad: los logs '
                  'persisten en texto plano en sistemas de observabilidad '
                  '(ELK, CloudWatch, etc.) y pueden ser accedidos por personal '
                  'no autorizado.',
              correctionMessage:
                  'Elimina "$keyName" del metadata. Alternativas: '
                  '(1) Usa un ID no sensible (userId, requestId). '
                  '(2) Aplica masking: "${keyName}Masked": "***\${$keyName.substring($keyName.length - 4)}". '
                  '(3) Loguea solo la presencia: "${keyName}Present": true.',
            ),
          );
        }
      }
    }
  }

  /// Checks positional string arguments for sensitive patterns.
  void _checkMessageArguments(
    ArgumentList args,
    String methodName,
    DiagnosticReporter reporter,
  ) {
    for (final arg in args.arguments) {
      // Skip named arguments (already handled metadata)
      if (arg is NamedExpression) continue;

      if (arg is StringLiteral) {
        final value = arg.stringValue;
        if (value != null) {
          _checkStringForSensitiveData(arg, value, methodName, reporter);
        }
      }

      // Check string interpolation
      if (arg is StringInterpolation) {
        _checkInterpolationForSensitiveData(arg, methodName, reporter);
      }
    }
  }

  void _checkStringForSensitiveData(
    AstNode node,
    String value,
    String methodName,
    DiagnosticReporter reporter,
  ) {
    for (final pattern in _sensitiveStringPatterns) {
      if (pattern.hasMatch(value)) {
        reporter.atNode(
          node,
          LintCode(
            name: 'no_sensitive_data_in_log_metadata',
            problemMessage: 'Posible dato sensible en mensaje de '
                'AppLoggerService.$methodName(). '
                'Se detectó un patrón de credencial en el literal de texto. '
                'Los logs con credenciales violan OWASP A09 y pueden exponer '
                'datos en sistemas de observabilidad.',
            correctionMessage: 'Elimina la credencial del mensaje. '
                'Usa identificadores no sensibles para trazabilidad. '
                'Si necesitas confirmar presencia de un token, loguea solo '
                '"tokenPresent: true" sin el valor.',
          ),
        );
        return; // Report once per argument
      }
    }
  }

  void _checkInterpolationForSensitiveData(
    StringInterpolation node,
    String methodName,
    DiagnosticReporter reporter,
  ) {
    // Check the literal parts for sensitive patterns
    for (final element in node.elements) {
      if (element is InterpolationString) {
        final value = element.value;
        for (final pattern in _sensitiveStringPatterns) {
          if (pattern.hasMatch(value)) {
            reporter.atNode(
              node,
              LintCode(
                name: 'no_sensitive_data_in_log_metadata',
                problemMessage:
                    'Posible dato sensible en mensaje interpolado de '
                    'AppLoggerService.$methodName(). '
                    'Se detectó un patrón de credencial. '
                    'Los logs con credenciales violan OWASP A09.',
                correctionMessage: 'Elimina la credencial del mensaje. '
                    'Usa identificadores no sensibles para trazabilidad.',
              ),
            );
            return;
          }
        }
      }
    }
  }

  bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    // Exact match (e.g. 'token', 'password', 'apiKey')
    if (_sensitiveKeys.contains(lower)) return true;
    // CamelCase compound ending with sensitive term (e.g. 'authToken', 'userPassword')
    // but NOT 'tokenPresent', 'tokenSuffix' where the sensitive word is a prefix
    return _sensitiveKeys.any((sensitive) => lower.endsWith(sensitive));
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
}

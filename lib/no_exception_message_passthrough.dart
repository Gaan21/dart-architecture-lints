import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prevents raw exception messages from being passed through
/// layers toward the UI.
///
/// Detects patterns where exception messages are forwarded through function
/// arguments or fallback expressions, even when they don't reach a UI widget
/// directly. These passthrough patterns allow raw messages to eventually
/// leak to the user in ways that are hard to track.
///
/// Detected patterns:
/// 1. `error.code ?? error.message`  — fallback to raw message
/// 2. Named args that forward raw messages: `details: error.message`,
///    `reason: error.message`, `error: exception.toString()`, etc.
/// 3. String interpolations in argument position: `'msg: ${error.message}'`
/// 4. Exception constructors forwarding backend/raw payload to `message`:
///    `RepositoryException(model.error ?? 'Error', code: ...)`
///
/// Scope: all layers (domain, data, presentation).
class NoExceptionMessagePassthrough extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoExceptionMessagePassthrough].
  const NoExceptionMessagePassthrough() : super(code: _code);

  /// Named parameter names that suggest user-visible message forwarding.
  static const _messageArgNames = {
    'message',
    'details',
    'description',
    'reason',
    'error',
    'cause',
    'userMessage',
    'displayMessage',
    'body',
    'subtitle',
    'hint',
  };

  /// Typical backend/raw payload fields that should not flow to UI directly.
  static const _rawPayloadPropertyNames = {
    'error',
    'errorDetail',
    'details',
    'detail',
    'reason',
    'message',
    'msg',
  };

  static const _code = LintCode(
    name: 'no_exception_message_passthrough',
    problemMessage:
        'Se está reenviando un mensaje crudo de excepción hacia la UI. '
        'Los mensajes de error al usuario deben usar códigos i18n estables, '
        'no strings de excepción que pueden cambiar y exponer detalles internos.',
    correctionMessage:
        'Usa el campo "code" de la excepción (estable) en lugar del mensaje crudo:\n'
        '  // ❌ MAL: reenvía mensaje crudo\n'
        '  final userMsg = error.code ?? error.message;\n'
        '  throw AppException(details: innerError.message);\n'
        '  throw RepositoryException(model.error ?? \'Error\', code: ...);\n'
        '\n'
        '  // ✅ BIEN: usa código estable\n'
        '  final code = error.code ?? AppErrorCodes.unknown;\n'
        '  throw AppException(code: innerError.code ?? AppErrorCodes.network);',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Exclude tests — assertion helpers often forward messages intentionally.
    final path = resolver.source.uri.path;
    if (path.contains('/test/') ||
        path.contains('/integration_test/') ||
        path.endsWith('_test.dart')) {
      return;
    }

    // Pattern 1: `error.code ?? error.message`
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (node.operator.lexeme != '??') return;

      final right = node.rightOperand;
      if (_containsRawExceptionPayload(right) ||
          _isRawPayloadProperty(right) ||
          _isRawMessageVariable(right)) {
        reporter.atNode(right, _code);
      }
    });

    // Pattern 2 & 3 and constructor passthrough.
    context.registry.addArgumentList((ArgumentList node) {
      final parent = node.parent;
      final bool isExceptionCtor = parent is InstanceCreationExpression &&
          _looksLikeExceptionCtor(parent);

      for (int i = 0; i < node.arguments.length; i++) {
        final arg = node.arguments[i];

        if (arg is NamedExpression) {
          final paramName = arg.name.label.name;
          if (!_messageArgNames.contains(paramName)) continue;

          final value = arg.expression;
          if (_containsRawExceptionPayload(value) ||
              _isRawPayloadProperty(value) ||
              _isRawMessageVariable(value)) {
            reporter.atNode(value, _code);
            continue;
          }

          if (value is StringInterpolation) {
            for (final element in value.elements) {
              if (element is! InterpolationExpression) continue;
              if (_containsRawExceptionPayload(element.expression) ||
                  _isRawPayloadProperty(element.expression) ||
                  _isRawMessageVariable(element.expression)) {
                reporter.atNode(element, _code);
              }
            }
          }
          continue;
        }

        // Positional message payload in exception constructors:
        // ExceptionType(<message>, ...)
        if (isExceptionCtor && i == 0) {
          if (_containsRawExceptionPayload(arg) ||
              _isRawPayloadProperty(arg) ||
              _isRawMessageVariable(arg)) {
            reporter.atNode(arg, _code);
          }
        }
      }
    });
  }

  bool _looksLikeExceptionCtor(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;
    return typeName.endsWith('Exception') || typeName.endsWith('Failure');
  }

  bool _containsRawExceptionPayload(Expression expr) {
    if (_isRawExceptionMessage(expr)) return true;

    if (expr is ParenthesizedExpression) {
      return _containsRawExceptionPayload(expr.expression);
    }

    if (expr is ConditionalExpression) {
      return _containsRawExceptionPayload(expr.thenExpression) ||
          _containsRawExceptionPayload(expr.elseExpression);
    }

    if (expr is BinaryExpression && expr.operator.lexeme == '??') {
      return _containsRawExceptionPayload(expr.leftOperand) ||
          _containsRawExceptionPayload(expr.rightOperand) ||
          _isRawPayloadProperty(expr.leftOperand) ||
          _isRawPayloadProperty(expr.rightOperand) ||
          _isRawMessageVariable(expr.leftOperand) ||
          _isRawMessageVariable(expr.rightOperand);
    }

    if (expr is StringInterpolation) {
      for (final element in expr.elements) {
        if (element is! InterpolationExpression) continue;
        if (_containsRawExceptionPayload(element.expression) ||
            _isRawPayloadProperty(element.expression) ||
            _isRawMessageVariable(element.expression)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isRawPayloadProperty(Expression expr) {
    if (expr is PrefixedIdentifier) {
      return _rawPayloadPropertyNames.contains(expr.identifier.name) &&
          _looksLikeRawPayloadCarrier(expr.prefix.name);
    }

    if (expr is PropertyAccess) {
      final propertyName = expr.propertyName.name;
      if (!_rawPayloadPropertyNames.contains(propertyName)) return false;
      final target = expr.target;
      return target is SimpleIdentifier &&
          _looksLikeRawPayloadCarrier(target.name);
    }

    return false;
  }

  bool _isRawMessageVariable(Expression expr) {
    if (expr is! SimpleIdentifier) return false;
    final normalized = expr.name.toLowerCase();
    return normalized == 'errormessage' ||
        normalized == 'exceptionmessage' ||
        normalized == 'backendmessage' ||
        normalized == 'rawmessage' ||
        normalized.endsWith('errormessage') ||
        normalized.endsWith('exceptionmessage') ||
        normalized.endsWith('backendmessage');
  }

  bool _looksLikeRawPayloadCarrier(String name) {
    final normalized = name.toLowerCase();
    return normalized == 'model' ||
        normalized == 'response' ||
        normalized == 'result' ||
        normalized == 'payload' ||
        normalized == 'data' ||
        normalized == 'json' ||
        normalized.contains('response') ||
        normalized.contains('payload') ||
        normalized.contains('backend') ||
        normalized.contains('model') ||
        normalized.contains('dto') ||
        normalized.contains('result');
  }

  /// Returns true if [expr] is a raw exception message access:
  /// - `error.message`  (PrefixedIdentifier or PropertyAccess)
  /// - `error.toString()`
  bool _isRawExceptionMessage(Expression expr) {
    // error.message (PrefixedIdentifier form)
    if (expr is PrefixedIdentifier) {
      return expr.identifier.name == 'message' &&
          _looksLikeExceptionVar(expr.prefix.name);
    }

    // result.error.message (PropertyAccess form)
    if (expr is PropertyAccess) {
      if (expr.propertyName.name == 'message') {
        final target = expr.target;
        if (target is SimpleIdentifier) {
          return _looksLikeExceptionVar(target.name);
        }
      }
      return false;
    }

    // error.toString()
    if (expr is MethodInvocation) {
      if (expr.methodName.name == 'toString') {
        final target = expr.target;
        if (target is SimpleIdentifier) {
          return _looksLikeExceptionVar(target.name);
        }
      }
    }

    return false;
  }
}

/// Variable name heuristics to identify exception carriers.
bool _looksLikeExceptionVar(String name) {
  const exactNames = {'error', 'err', 'e', 'exception', 'ex', 'failure'};
  if (exactNames.contains(name)) return true;
  return name.endsWith('Exception') ||
      name.endsWith('Error') ||
      name.endsWith('Failure') ||
      name.endsWith('AppException') ||
      name.toLowerCase().contains('exception') ||
      name.toLowerCase().contains('error');
}

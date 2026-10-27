import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prevents raw exception messages from reaching the user.
///
/// Accessing `error.message`, `exception.toString()`, or similar raw exception
/// data directly inside UI notification calls (Text, SnackBar, showError, etc.)
/// violates the i18n contract: messages shown to users must use stable i18n codes,
/// not free-form exception strings that can change and leak internal details.
///
/// Scope: presentation layer only.
class NoRawExceptionMessageToUser extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoRawExceptionMessageToUser].
  NoRawExceptionMessageToUser() : super(code: _code);

  /// UI widget/function names whose arguments must not contain raw exception messages.
  static const _uiCallees = {
    // Flutter widgets
    'Text',
    'SelectableText',
    'SnackBar',
    'AlertDialog',
    'SimpleDialog',
    'Tooltip',
    // Common project helpers
    'ShowSnackbar',
    'showSnackbar',
    'showError',
    'showWarning',
    'showMessage',
    'showInfo',
    'showAlert',
    'showDialog',
    'showToast',
    'showNotification',
  };

  static const _code = LintCode(
    'no_raw_exception_message_to_user',
    'No uses mensajes crudos de excepción directamente en componentes UI. '
        'Los mensajes de error al usuario deben venir de códigos i18n estables.',
    correctionMessage:
        'Usa un código de error estable y localización para el mensaje:\n'
        '  // ❌ MAL\n'
        '  Text(error.message)\n'
        '  showError(exception.toString())\n'
        '\n'
        '  // ✅ BIEN\n'
        '  Text(context.l10n.errorMessageFor(error.code))\n'
        '  showError(AppLocalizations.of(context).unknownError)',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    // Only enforce in the presentation layer
    if (!resolver.uri.path.contains('/presentation/')) return;

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final typeName = node.constructorName.type.name.lexeme;
      if (!_uiCallees.contains(typeName)) return;
      _checkArguments(node.argumentList, reporter);
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      if (!_uiCallees.contains(methodName)) return;
      _checkArguments(node.argumentList, reporter);
    });
  }

  void _checkArguments(ArgumentList argumentList, DiagnosticReporter reporter) {
    final visitor = _RawMessageVisitor(reporter, _code);
    argumentList.visitChildren(visitor);
  }
}

/// Variable name patterns that suggest exception/error carriers.
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

/// Variable name patterns that suggest a raw message payload.
bool _looksLikeRawMessageIdentifier(String name) {
  final normalized = name.toLowerCase();
  return normalized == 'errormessage' ||
      normalized == 'exceptionmessage' ||
      normalized == 'backendmessage' ||
      normalized == 'rawmessage' ||
      normalized.endsWith('errormessage') ||
      normalized.endsWith('exceptionmessage') ||
      normalized.endsWith('backendmessage');
}

/// Visits argument sub-trees to find raw exception message accesses.
class _RawMessageVisitor extends RecursiveAstVisitor<void> {
  final DiagnosticReporter reporter;
  final LintCode code;

  _RawMessageVisitor(this.reporter, this.code);

  /// `error.message` as a PrefixedIdentifier (most common form)
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    super.visitPrefixedIdentifier(node);
    // Dedup: when directly inside `${...}`, visitInterpolationExpression
    // already reports at the interpolation level. Skip here to avoid
    // emitting two diagnostics for the same violation.
    if (node.parent is InterpolationExpression) return;
    if (node.identifier.name == 'message' &&
        _looksLikeExceptionVar(node.prefix.name)) {
      // Dedup: skip if this node is the RHS of a ?? expression.
      // `no_exception_message_passthrough` already reports that case;
      // emitting both rules on the same node adds noise without value.
      if (_isNullCoalesceRhs(node)) return;
      reporter.atNode(node, code);
    }
  }

  /// `error.message` as a PropertyAccess (chained form, e.g. result.error.message)
  @override
  void visitPropertyAccess(PropertyAccess node) {
    super.visitPropertyAccess(node);
    if (node.propertyName.name == 'message') {
      final target = node.target;
      if (target is SimpleIdentifier && _looksLikeExceptionVar(target.name)) {
        if (_isNullCoalesceRhs(node)) return;
        reporter.atNode(node, code);
      }
    }
  }

  /// `error.toString()` or `exception.toString()`
  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    // Dedup: when directly inside `${...}`, visitInterpolationExpression
    // already reports at the interpolation level. Skip here to avoid
    // emitting two diagnostics for the same violation.
    if (node.parent is InterpolationExpression) return;
    if (node.methodName.name == 'toString') {
      final target = node.target;
      if (target is SimpleIdentifier && _looksLikeExceptionVar(target.name)) {
        if (_isNullCoalesceRhs(node)) return;
        reporter.atNode(node, code);
      }
    }
  }

  /// `showError(errorMessage)` where errorMessage is likely raw payload.
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);
    if (_looksLikeRawMessageIdentifier(node.name)) {
      reporter.atNode(node, code);
    }
  }

  /// String interpolations: `'Error: ${error.message}'`
  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    super.visitInterpolationExpression(node);
    final expr = node.expression;

    // ${error.message}
    if (expr is PrefixedIdentifier &&
        expr.identifier.name == 'message' &&
        _looksLikeExceptionVar(expr.prefix.name)) {
      if (!_isNullCoalesceRhs(expr)) reporter.atNode(node, code);
    }

    // ${error.toString()}
    if (expr is MethodInvocation &&
        expr.methodName.name == 'toString' &&
        expr.target is SimpleIdentifier &&
        _looksLikeExceptionVar((expr.target as SimpleIdentifier).name)) {
      if (!_isNullCoalesceRhs(expr)) reporter.atNode(node, code);
    }
  }

  /// Returns true when [node] is the right-hand operand of a `??` expression.
  ///
  /// In that case `no_exception_message_passthrough` already covers the
  /// violation; reporting both rules on the same site creates duplicate noise.
  bool _isNullCoalesceRhs(AstNode node) {
    final parent = node.parent;
    return parent is BinaryExpression &&
        parent.operator.lexeme == '??' &&
        parent.rightOperand == node;
  }
}

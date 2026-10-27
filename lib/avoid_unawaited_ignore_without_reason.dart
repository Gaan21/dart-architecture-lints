import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Secondary lint rule that detects `// ignore: <rule>` comments targeting
/// the unawaited-governance rules without an accompanying
/// `// ignore-reason: <reason>` justification.
///
/// Rules covered:
///   - `avoid_unawaited`
///   - `avoid_async_in_provider_create`
///   - `avoid_async_wrapper_hides_unawaited`
///
/// This ensures that even when a rule is suppressed via `// ignore:`, the
/// developer must provide a reason for the suppression. A rule may be named
/// bare (`avoid_unawaited`) or with the plugin prefix that the analyzer
/// requires to suppress it (`dart_architecture_lints/avoid_unawaited`).
class AvoidUnawaitedIgnoreWithoutReasonLint
    extends GeneratedSkippingDartLintRule {
  AvoidUnawaitedIgnoreWithoutReasonLint() : super(code: _code);

  static const _pluginPrefix = 'dart_architecture_lints/';

  /// The set of rule names that require an `// ignore-reason:` when ignored.
  static const _targetedRules = {
    'avoid_unawaited',
    'avoid_async_in_provider_create',
    'avoid_async_wrapper_hides_unawaited',
  };

  static const _code = LintCode(
    'avoid_unawaited_ignore_without_reason',
    '`// ignore: <regla-unawaited>` sin justificación. '
        'Si necesitas suprimir la regla, añade `// ignore-reason: <motivo>` '
        'en la misma línea o la línea anterior explicando por qué es seguro '
        'ignorar el aviso.',
    correctionMessage:
        'Añade un comentario `// ignore-reason: <motivo>` antes del '
        '`// ignore: <regla>`. Ejemplo:\n'
        '  // ignore-reason: caso legacy, se migrará en el próximo sprint\n'
        '  // ignore: avoid_unawaited\n'
        '  unawaited(legacy.doThing());\n'
        'Reglas cubiertas: avoid_unawaited | avoid_async_in_provider_create | '
        'avoid_async_wrapper_hides_unawaited',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final lineInfo = unit.lineInfo;
      final ignoreComments = <_IgnoreComment>[];

      // Walk the token stream to find all targeted ignore comments
      Token? token = unit.beginToken;
      while (token != null && token.type != TokenType.EOF) {
        Token? comment = token.precedingComments;
        while (comment != null) {
          final text = comment.lexeme.trim();
          if (_isTargetedIgnore(text)) {
            final line = lineInfo.getLocation(comment.offset).lineNumber;
            ignoreComments.add(
              _IgnoreComment(
                line: line,
                offset: comment.offset,
                length: comment.length,
              ),
            );
          }
          comment = comment.next;
        }
        token = token.next;
      }

      // For each targeted ignore comment, check for a valid ignore-reason
      for (final ignoreComment in ignoreComments) {
        if (!_hasIgnoreReason(unit, ignoreComment.line)) {
          reporter.atOffset(
            diagnosticCode: _code,
            offset: ignoreComment.offset,
            length: ignoreComment.length,
          );
        }
      }
    });
  }

  /// Returns true if the comment text is `// ignore: <rules>` where at least
  /// one of [_targetedRules] appears in the rule list, bare or prefixed.
  bool _isTargetedIgnore(String text) {
    if (!text.startsWith('//')) return false;
    final content = text.substring(2).trim();

    if (!content.startsWith('ignore:')) return false;

    final rules = content.substring('ignore:'.length).trim();
    final ruleList = rules
        .split(',')
        .map((r) => r.trim())
        .map(
          (r) => r.startsWith(_pluginPrefix)
              ? r.substring(_pluginPrefix.length)
              : r,
        )
        .toSet();
    return ruleList.intersection(_targetedRules).isNotEmpty;
  }

  /// Checks whether there is a valid `// ignore-reason: <non-empty reason>`
  /// on the same line or the immediately preceding line.
  bool _hasIgnoreReason(CompilationUnit unit, int ignoreLine) {
    final lineInfo = unit.lineInfo;

    Token? token = unit.beginToken;
    while (token != null && token.type != TokenType.EOF) {
      Token? comment = token.precedingComments;
      while (comment != null) {
        final commentLine = lineInfo.getLocation(comment.offset).lineNumber;
        if (commentLine == ignoreLine || commentLine == ignoreLine - 1) {
          if (_isValidIgnoreReason(comment.lexeme)) {
            return true;
          }
        }
        comment = comment.next;
      }
      token = token.next;
    }

    return false;
  }

  /// Validates that the comment matches `// ignore-reason: <non-empty reason>`.
  bool _isValidIgnoreReason(String commentText) {
    final trimmed = commentText.trim();
    if (!trimmed.startsWith('//')) return false;

    final afterSlashes = trimmed.substring(2).trim();
    if (!afterSlashes.startsWith('ignore-reason:')) return false;

    final reason = afterSlashes.substring('ignore-reason:'.length).trim();
    return reason.isNotEmpty;
  }
}

class _IgnoreComment {
  final int line;
  final int offset;
  final int length;

  const _IgnoreComment({
    required this.line,
    required this.offset,
    required this.length,
  });
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Lint rule that detects `unawaited(...)` calls without a structured justification
/// comment in the format `// unawaited-ok: <category> - <reason>`.
///
/// Valid categories:
///   dispose-sync | callback-sync | telemetry/logging |
///   best-effort-cleanup | post-frame-init | prefetch-noncritical
///
/// The method passed to unawaited MUST be NO-THROW (try/catch + central logging
/// internally) since errors inside fire-and-forget Futures are otherwise lost.
class AvoidUnawaitedLint extends GeneratedSkippingDartLintRule {
  const AvoidUnawaitedLint() : super(code: _codeNoJustification);

  static const _validCategories = {
    'dispose-sync',
    'callback-sync',
    'telemetry/logging',
    'best-effort-cleanup',
    'post-frame-init',
    'prefetch-noncritical',
  };

  // Two codes share the same rule name so both are suppressed by
  // `// ignore: avoid_unawaited` and controlled via analysis_options.

  static const _codeNoJustification = LintCode(
    name: 'avoid_unawaited',
    problemMessage:
        'Uso de `unawaited(...)` sin justificación. '
        'Formato requerido: `// unawaited-ok: <categoría> - <motivo>`.',
    correctionMessage:
        'Opciones: (1) usa `async`/`await` si el resultado afecta estado/UI; '
        '(2) propaga el Future al ViewModel; '
        '(3) si estás en Provider.create, mueve a '
        '`addPostFrameCallback((_) { unawaited(...); })`; '
        '(4) si es fire-and-forget legítimo, añade '
        '`// unawaited-ok: <categoría> - <motivo>` y asegura que el método '
        'sea NO-THROW (try/catch + logging central). '
        'Categorías válidas: '
        'dispose-sync | callback-sync | telemetry/logging | '
        'best-effort-cleanup | post-frame-init | prefetch-noncritical',
  );

  static const _codeInvalidCategory = LintCode(
    name: 'avoid_unawaited',
    problemMessage:
        'Categoría en `// unawaited-ok:` inválida o formato incorrecto. '
        'Formato requerido: `// unawaited-ok: <categoría> - <motivo>`.',
    correctionMessage:
        'Usa una categoría válida: '
        'dispose-sync | callback-sync | telemetry/logging | '
        'best-effort-cleanup | post-frame-init | prefetch-noncritical. '
        'Ejemplo: `// unawaited-ok: dispose-sync - cerrando StreamController en dispose()`. '
        'El método llamado debe ser NO-THROW (try/catch + logging central).',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      _checkMethodInvocation(node, reporter);
    });
  }

  void _checkMethodInvocation(
    MethodInvocation node,
    DiagnosticReporter reporter,
  ) {
    if (node.methodName.name != 'unawaited') return;

    // Verify it resolves to dart:async's unawaited (avoid false positives)
    final resolvedElement = node.methodName.element;
    if (resolvedElement != null) {
      final lib = resolvedElement.library;
      if (lib != null && !lib.uri.toString().startsWith('dart:async')) {
        return;
      }
    }

    final codeToReport = _checkJustification(node);
    if (codeToReport != null) {
      reporter.atNode(node, codeToReport);
    }
  }

  /// Returns null if a valid structured justification is found,
  /// or the [LintCode] to report if not.
  LintCode? _checkJustification(AstNode node) {
    final unit = node.root;
    if (unit is! CompilationUnit) return _codeNoJustification;

    final lineInfo = unit.lineInfo;
    final nodeLine = lineInfo.getLocation(node.offset).lineNumber;

    bool foundInvalidFormat = false;

    Token? token = unit.beginToken;
    while (token != null && token.type != TokenType.EOF) {
      Token? comment = token.precedingComments;
      while (comment != null) {
        final commentLine = lineInfo.getLocation(comment.offset).lineNumber;
        // Accept comment on same line or the immediately preceding line
        if (commentLine == nodeLine || commentLine == nodeLine - 1) {
          final result = _parseUnawaitedOkComment(comment.lexeme);
          if (result == _ParseResult.valid) return null;
          if (result == _ParseResult.invalidFormat) foundInvalidFormat = true;
        }
        comment = comment.next;
      }
      token = token.next;
    }

    return foundInvalidFormat ? _codeInvalidCategory : _codeNoJustification;
  }

  /// Parses a comment lexeme looking for `// unawaited-ok: <category> - <reason>`.
  ///
  /// Returns:
  /// - [_ParseResult.valid]: well-formed comment with valid category and non-empty reason.
  /// - [_ParseResult.invalidFormat]: starts with `// unawaited-ok:` but has
  ///   missing separator, invalid category, or empty reason.
  /// - [_ParseResult.notOk]: not a `// unawaited-ok:` comment; ignore.
  _ParseResult _parseUnawaitedOkComment(String commentText) {
    final trimmed = commentText.trim();
    if (!trimmed.startsWith('//')) return _ParseResult.notOk;

    final afterSlashes = trimmed.substring(2).trim();
    if (!afterSlashes.startsWith('unawaited-ok:')) return _ParseResult.notOk;

    final content = afterSlashes.substring('unawaited-ok:'.length).trim();
    if (content.isEmpty) return _ParseResult.invalidFormat;

    // Require "category - reason" separated by ' - '
    final dashIndex = content.indexOf(' - ');
    if (dashIndex == -1) return _ParseResult.invalidFormat;

    final category = content.substring(0, dashIndex).trim();
    final reason = content.substring(dashIndex + 3).trim();

    if (!_validCategories.contains(category)) return _ParseResult.invalidFormat;
    if (reason.isEmpty) return _ParseResult.invalidFormat;

    return _ParseResult.valid;
  }
}

enum _ParseResult { valid, invalidFormat, notOk }

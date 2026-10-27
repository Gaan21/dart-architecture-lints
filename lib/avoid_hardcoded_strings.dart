import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Simple rule to detect hardcoded strings using working structure
class AvoidHardcodedStrings extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [AvoidHardcodedStrings].
  AvoidHardcodedStrings() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'avoid_hardcoded_strings',
    'Hardcoded strings should be externalized for internationalization. This string appears to be user-facing content.',
    correctionMessage: 'Move this string to a localization file (e.g., AppLocalizations, strings.dart) or use i18n/l10n solutions for better maintainability and translation support.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    // Only apply in presentation and use_cases layers
    final filePath = resolver.path;
    if (!_shouldCheckFile(filePath)) return;

    context.registry.addStringLiteral((StringLiteral node) {
      final s = node.stringValue;

      if (s != null &&
          s.length > 1 && // al menos 2 caracteres
          !s.contains('.') &&
          !s.contains('/') &&
          !s.contains('#') &&
          !s.contains('_') &&
          !s.contains(':')) {
        reporter.atNode(node, _code);
      }
    });
  }

  /// Checks if the file should be analyzed for hardcoded strings.
  bool _shouldCheckFile(String filePath) {
    final segments = filePath.toLowerCase().split('/');

    // Exclude test files
    if (segments.any((segment) => segment.contains('test'))) {
      return false;
    }

    // Only check presentation and use_cases layers
    return segments.contains('presentation') || segments.contains('usecases');
  }
}

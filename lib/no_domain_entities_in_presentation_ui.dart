import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:dart_architecture_lints/timezone_safety_utils.dart';

class NoDomainEntitiesInPresentationUiLint
    extends GeneratedSkippingDartLintRule {
  NoDomainEntitiesInPresentationUiLint({
    this.config = const NoDomainEntitiesInPresentationUiConfig(),
  }) : super(code: _code);

  final NoDomainEntitiesInPresentationUiConfig config;

  static const _code = LintCode(
    'no_domain_entities_in_presentation_ui',
    'Presentation UI must not depend on domain entities directly; use UiModel contracts from presentation/models.',
    correctionMessage: 'Replace domain entity imports with presentation/models/*_ui_model.dart contracts and keep mapping inside explicit *_ui_mapper.dart files.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final filePath = normalizeLintPath(resolver.path);
    if (!config.matchesTargetPath(filePath)) return;
    if (config.isAllowlistedPath(filePath)) return;

    final packageName =
        config.projectPackageName ??
        analyzedPackageName(resolver.uri, context.packageName);
    context.registry.addImportDirective((ImportDirective node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;
      if (!_isDomainEntitiesImport(uri, packageName)) return;
      reporter.atNode(node.uri, _code);
    });
  }

  /// The analyzed library's own package: its `package:` URI when available,
  /// otherwise the name in the nearest `pubspec.yaml` above the file.
  static String analyzedPackageName(Uri source, String pubspecName) =>
      source.scheme == 'package' && source.pathSegments.isNotEmpty
      ? source.pathSegments.first
      : pubspecName;

  bool _isDomainEntitiesImport(String importUri, String packageName) {
    final entitiesPrefix = 'package:$packageName/domain/entities';
    return importUri == '$entitiesPrefix.dart' ||
        importUri.startsWith('$entitiesPrefix/');
  }
}

class NoDomainEntitiesInPresentationUiConfig {
  const NoDomainEntitiesInPresentationUiConfig({
    this.projectPackageName,
    this.includeGlobs = _defaultIncludeGlobs,
    this.allowedFileGlobs = _defaultAllowedFileGlobs,
  });

  /// Explicit package name; null uses the analyzed package's own name.
  final String? projectPackageName;
  final List<String> includeGlobs;
  final List<String> allowedFileGlobs;

  static const _defaultIncludeGlobs = [
    '**/lib/presentation/screens/**',
    '**/lib/presentation/widgets/**',
  ];

  static const _defaultAllowedFileGlobs = [
    '**/lib/presentation/**/*_ui_mapper.dart',
  ];

  bool matchesTargetPath(String normalizedPath) {
    return matchesAnyGlob(normalizedPath, includeGlobs);
  }

  bool isAllowlistedPath(String normalizedPath) {
    if (allowedFileGlobs.isEmpty) return false;
    return matchesAnyGlob(normalizedPath, allowedFileGlobs);
  }
}

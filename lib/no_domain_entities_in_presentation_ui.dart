import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:dart_architecture_lints/timezone_safety_utils.dart';

class NoDomainEntitiesInPresentationUiLint
    extends GeneratedSkippingDartLintRule {
  const NoDomainEntitiesInPresentationUiLint({
    this.config = const NoDomainEntitiesInPresentationUiConfig(),
  }) : super(code: _code);

  final NoDomainEntitiesInPresentationUiConfig config;

  static const _code = LintCode(
    name: 'no_domain_entities_in_presentation_ui',
    problemMessage:
        'Presentation UI must not depend on domain entities directly; use UiModel contracts from presentation/models.',
    correctionMessage:
        'Replace domain entity imports with presentation/models/*_ui_model.dart contracts and keep mapping inside explicit *_ui_mapper.dart files.',
  );

  static NoDomainEntitiesInPresentationUiLint fromConfigs(
    CustomLintConfigs configs,
  ) {
    final options = readRuleOptions(configs, _code.name);
    return NoDomainEntitiesInPresentationUiLint(
      config: NoDomainEntitiesInPresentationUiConfig.fromJson(options),
    );
  }

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = normalizeLintPath(resolver.path);
    if (!config.matchesTargetPath(filePath)) return;
    if (config.isAllowlistedPath(filePath)) return;

    final packageName =
        config.projectPackageName ??
        analyzedPackageName(resolver.source.uri, context.pubspec.name);
    context.registry.addImportDirective((ImportDirective node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;
      if (!_isDomainEntitiesImport(uri, packageName)) return;
      reporter.atNode(node.uri, _code);
    });
  }

  /// The analyzed library's own package: its `package:` URI when available,
  /// otherwise the analyzed project's pubspec name supplied by custom_lint.
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

  factory NoDomainEntitiesInPresentationUiConfig.fromJson(
    Map<String, Object?> json,
  ) {
    final packageNameRaw = json['project_package_name'];
    final packageName =
        packageNameRaw is String && packageNameRaw.trim().isNotEmpty
        ? packageNameRaw.trim()
        : null;

    return NoDomainEntitiesInPresentationUiConfig(
      projectPackageName: packageName,
      includeGlobs: readStringListOption(
        json,
        'include_globs',
        fallback: _defaultIncludeGlobs,
      ),
      allowedFileGlobs: readStringListOption(
        json,
        'allowed_file_globs',
        fallback: _defaultAllowedFileGlobs,
      ),
    );
  }

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

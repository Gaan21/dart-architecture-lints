import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:dart_architecture_lints/timezone_safety_utils.dart';

class NoDeviceLocalInPresentationLint extends GeneratedSkippingDartLintRule {
  NoDeviceLocalInPresentationLint({
    this.config = const NoDeviceLocalInPresentationConfig(),
  }) : super(code: _code);

  final NoDeviceLocalInPresentationConfig config;

  static const _code = LintCode(
    'no_device_local_in_presentation',
    'Avoid DateTime.toLocal() in presentation layer. Use backend timezone-aware values or approved time helper.',
    correctionMessage: 'Move timezone conversion to an approved time helper/service and keep presentation code timezone-safe.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final path = normalizeLintPath(resolver.path);
    if (!config.matchesPath(path)) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'toLocal') return;
      if (node.argumentList.arguments.isNotEmpty) return;

      final receiver = node.realTarget ?? node.target;
      if (receiver == null) return;

      if (config.isAllowedReceiver(receiver.toSource())) return;
      if (config.isInsideAllowedWrapper(node)) return;

      reporter.atNode(node.methodName, _code);
    });
  }
}

class NoDeviceLocalInPresentationConfig {
  const NoDeviceLocalInPresentationConfig({
    this.includeGlobs = _defaultIncludes,
    this.excludeGlobs = const [],
    this.allowedReceivers = const [],
    this.allowedWrappers = const [],
  });

  final List<String> includeGlobs;
  final List<String> excludeGlobs;
  final List<String> allowedReceivers;
  final List<String> allowedWrappers;

  static const _defaultIncludes = [
    '**/presentation/**',
    '**/ui/**',
    '**/screens/**',
    '**/widgets/**',
  ];

  bool matchesPath(String normalizedPath) {
    if (!matchesAnyGlob(normalizedPath, includeGlobs)) return false;
    if (excludeGlobs.isNotEmpty &&
        matchesAnyGlob(normalizedPath, excludeGlobs)) {
      return false;
    }
    return true;
  }

  bool isAllowedReceiver(String receiverSource) {
    if (allowedReceivers.isEmpty) return false;

    final compact = receiverSource.replaceAll(' ', '');
    return matchesAnyWildcard(compact, allowedReceivers) ||
        matchesAnyWildcard(receiverSource, allowedReceivers);
  }

  bool isInsideAllowedWrapper(AstNode node) {
    if (allowedWrappers.isEmpty) return false;

    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final names = _callCandidates(current);
        if (names.any(
          (candidate) => matchesAnyWildcard(candidate, allowedWrappers),
        )) {
          return true;
        }
      }
      current = current.parent;
    }

    return false;
  }

  List<String> _callCandidates(MethodInvocation node) {
    final methodName = node.methodName.name;
    final target = node.target;
    if (target == null) return [methodName];

    final source = target.toSource();
    final compactSource = source.replaceAll(' ', '');
    return [methodName, '$source.$methodName', '$compactSource.$methodName'];
  }
}

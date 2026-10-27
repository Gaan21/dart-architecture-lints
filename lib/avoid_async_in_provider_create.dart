import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Lint rule that detects `unawaited(...)` calls executed directly inside
/// a Provider.create / ChangeNotifierProvider.create (or similar) closure
/// without being wrapped in `addPostFrameCallback`.
///
/// Async operations inside Provider.create run during the widget build phase.
/// Mutating state at build time can cause "setState during build" errors and
/// subtle UI race conditions.
///
/// **Safe pattern:**
/// ```dart
/// create: (ctx) {
///   WidgetsBinding.instance.addPostFrameCallback((_) {
///     // unawaited-ok: post-frame-init - initializing VM after build
///     unawaited(vm.init());
///   });
///   return vm;
/// }
/// ```
///
/// **Detection heuristic (conservative):** looks for a [NamedArgument] named
/// `create` or `update` whose parent [InstanceCreationExpression] has a type
/// name containing "Provider". This covers the most common provider packages
/// (provider, riverpod-style wrappers) while avoiding false positives from
/// unrelated classes that happen to have a `create` parameter.
///
/// **Limitation:** custom Provider wrappers with different outer class names
/// (e.g. `AppState.create(...)`) are NOT detected by this heuristic.
class AvoidAsyncInProviderCreateLint extends GeneratedSkippingDartLintRule {
  AvoidAsyncInProviderCreateLint() : super(code: _code);

  static const _code = LintCode(
    'avoid_async_in_provider_create',
    'Async en build-time prohibido: `unawaited(...)` dentro de '
        'Provider.create puede mutar estado antes de que el árbol de '
        'widgets esté listo.',
    correctionMessage:
        'Mueve la llamada async dentro de '
        '`WidgetsBinding.instance.addPostFrameCallback((_) { unawaited(...); })` '
        'dentro del closure create. '
        'Ejemplo: `create: (ctx) { WidgetsBinding.instance'
        '.addPostFrameCallback((_) { unawaited(vm.init()); }); return vm; }`',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'unawaited') return;

      // Verify it resolves to dart:async's unawaited (avoid false positives)
      final resolvedElement = node.methodName.element;
      if (resolvedElement != null) {
        final lib = resolvedElement.library;
        if (lib != null && !lib.uri.toString().startsWith('dart:async')) {
          return;
        }
      }

      if (_isInProviderCreateWithoutPostFrame(node)) {
        reporter.atNode(node, _code);
      }
    });
  }

  /// Returns true when [node] is inside a Provider `create`/`update` closure
  /// but NOT inside an `addPostFrameCallback` callback.
  ///
  /// Walks ancestors from innermost to outermost:
  /// - If we first hit `addPostFrameCallback` → we are inside post-frame → safe.
  /// - If we first hit a `create`/`update` [NamedArgument] belonging to a
  ///   Provider [InstanceCreationExpression] → unsafe.
  bool _isInProviderCreateWithoutPostFrame(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      // addPostFrameCallback is safe: mutations happen after build
      if (current is MethodInvocation &&
          current.methodName.name == 'addPostFrameCallback') {
        return false;
      }

      // Check for Provider.create / Provider.update named argument
      if (current is NamedArgument) {
        final argName = current.name.lexeme;
        if (argName == 'create' || argName == 'update') {
          final argList = current.parent;
          if (argList is ArgumentList) {
            final instanceCreation = argList.parent;
            if (instanceCreation is InstanceCreationExpression) {
              final typeName = _resolvedOrLexemeName(
                instanceCreation.constructorName.type,
              );
              // Heuristic: flag when constructor type name contains 'Provider'
              // Covers: Provider, ChangeNotifierProvider, ProxyProvider,
              //         FutureProvider, StreamProvider, ListenableProvider, etc.
              if (typeName != null && typeName.contains('Provider')) {
                return true;
              }
            }
          }
        }
      }

      current = current.parent;
    }
    return false;
  }

  /// Returns the display name of a [NamedType], preferring the resolved type
  /// to avoid false positives from type aliases, falling back to lexeme.
  String? _resolvedOrLexemeName(NamedType type) {
    final resolved = type.type;
    if (resolved != null) {
      return resolved.getDisplayString();
    }
    // Fallback: unresolved AST (e.g. in IDE before analysis completes)
    return type.name.lexeme;
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Lint rule that detects the anti-pattern of wrapping a single `await`
/// inside an async callback to silently suppress the unawaited-Future warning:
///
/// ```dart
/// // BAD — hides the fact that the future is unawaited
/// scheduleMicrotask(() async { await doWork(); });
/// Timer.run(() async { await doWork(); });
/// Future(() async { await doWork(); });
/// ```
///
/// These patterns are functionally equivalent to `unawaited(doWork())` but
/// bypass the `avoid_unawaited` lint, breaking governance and hiding errors.
///
/// **Detection criteria (precise to minimise false positives):**
/// Only fires when the async function body contains **exactly one statement**
/// that is either:
/// - `ExpressionStatement(AwaitExpression(...))`  — `await expr;`
/// - `ReturnStatement(AwaitExpression(...))`       — `return await expr;`
///
/// Multi-statement async callbacks (legitimate orchestration) are not flagged.
///
/// **Correct alternatives:**
/// - Use `unawaited(doWork())` with `// unawaited-ok: <category> - <reason>`
///   if truly fire-and-forget (and ensure NO-THROW contract).
/// - Await properly inside an `async` method.
/// - In Provider.create: use `addPostFrameCallback((_) { unawaited(doWork()); })`.
class AvoidAsyncWrapperHidesUnawaitedLint extends GeneratedSkippingDartLintRule {
  const AvoidAsyncWrapperHidesUnawaitedLint() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_async_wrapper_hides_unawaited',
    problemMessage:
        'Anti-patrón: wrapper async con un solo `await` para ocultar un '
        'Future no-esperado. Esto evade la gobernanza de `avoid_unawaited`.',
    correctionMessage:
        'Alternativas: (1) usa `unawaited(expr)` con '
        '`// unawaited-ok: <categoría> - <motivo>` y asegura NO-THROW; '
        '(2) haz `await` correctamente en un método `async`; '
        '(3) en Provider.create, usa '
        '`addPostFrameCallback((_) { unawaited(expr); })`.',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Detect scheduleMicrotask(...) and Timer.run(...)
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (_isScheduleMicrotask(node) || _isTimerRun(node)) {
        _checkSingleAwaitCallback(node.argumentList, node, reporter);
      }
    });

    // Detect Future(...)  with unnamed constructor
    context.registry.addInstanceCreationExpression(
      (InstanceCreationExpression node) {
        if (_isUnnamedFutureConstructor(node)) {
          _checkSingleAwaitCallback(node.argumentList, node, reporter);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Target detection helpers
  // ---------------------------------------------------------------------------

  /// `scheduleMicrotask(...)` — top-level function, no target.
  bool _isScheduleMicrotask(MethodInvocation node) {
    return node.target == null &&
        node.methodName.name == 'scheduleMicrotask';
  }

  /// `Timer.run(...)` — static method called on `Timer` identifier.
  bool _isTimerRun(MethodInvocation node) {
    if (node.methodName.name != 'run') return false;
    final target = node.target;
    if (target is SimpleIdentifier) return target.name == 'Timer';
    // Handle import-prefixed access: `t.Timer.run(...)` if rare
    if (target is PrefixedIdentifier) return target.identifier.name == 'Timer';
    return false;
  }

  /// `Future(fn)` — unnamed constructor, e.g. `Future(() async { ... })`.
  bool _isUnnamedFutureConstructor(InstanceCreationExpression node) {
    // Must have no named constructor (Future.delayed, Future.value, etc.)
    if (node.constructorName.name != null) return false;
    final typeName = node.constructorName.type.name.lexeme;
    return typeName == 'Future';
  }

  // ---------------------------------------------------------------------------
  // Callback body check
  // ---------------------------------------------------------------------------

  /// Reports [reportNode] if [argumentList] contains a single async function
  /// literal whose body has exactly one `await` statement.
  void _checkSingleAwaitCallback(
    ArgumentList argumentList,
    AstNode reportNode,
    DiagnosticReporter reporter,
  ) {
    // Expect exactly one argument (the callback)
    if (argumentList.arguments.length != 1) return;

    final arg = argumentList.arguments.first;
    if (arg is! FunctionExpression) return;

    // Callback must be async
    if (!arg.body.isAsynchronous) return;

    final body = arg.body;
    if (body is! BlockFunctionBody) return;

    final statements = body.block.statements;
    if (statements.length != 1) return;

    if (_isSingleAwaitStatement(statements.first)) {
      reporter.atNode(reportNode, _code);
    }
  }

  /// Returns true for `await <expr>;` and `return await <expr>;`.
  bool _isSingleAwaitStatement(Statement stmt) {
    if (stmt is ExpressionStatement) {
      return stmt.expression is AwaitExpression;
    }
    if (stmt is ReturnStatement) {
      return stmt.expression is AwaitExpression;
    }
    return false;
  }
}

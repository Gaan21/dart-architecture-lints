import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:dart_architecture_lints/timezone_safety_utils.dart';

/// Detects `DateFormat(...).format(value)` calls for time patterns inside
/// presentation/UI files where the argument has not been converted through an
/// approved empresa time helper such as `toEmpresaLocalTime`.
/// **Phase 1 — file-level pre-scan** (`addCompilationUnit`):
/// Collects every variable name whose *initializer* is a time-pattern DateFormat
/// (e.g. `final f = DateFormat('HH:mm')`).  This set is used in Phase 2 to
/// recognise formatter variables with generic names (`f`, `fmt`, etc.).
/// **Phase 2 — per-invocation check** (`addMethodInvocation`):
/// For each `.format(arg)` call whose receiver is a time-format DateFormat:
///   1. Accept if `arg` is a direct approved-wrapper call (e.g. `toEmpresaLocalTime(...)`).
///   2. Accept if `arg` is a `SimpleIdentifier` that **resolves to a pre-converted
///      value in the correct lexical scope** — walking `Block` ancestors upward but
///      stopping at function/method declaration boundaries (see [_isPreConvertedInScope]).
///   3. Accept (opt-in) if `allow_utc_debug_context` is enabled and the call is
///      inside a `'... UTC'` string interpolation.
///   4. Report otherwise.
/// Given `f.format(local)`, the resolver scans upward through `Block` nodes
/// looking for the last statement that declares or assigns `local` *before* the
/// format call within that block.  It returns:
/// - **converted** → the last action was an initialisation/assignment from an
///   approved wrapper (stops, PASS).
/// - **notConverted** → the last action was a declaration or assignment from a
///   non-approved expression (stops, FAIL).  Inner declarations shadow outer ones.
/// - **unknown** → the variable is not declared or assigned in this block →
///   continue to outer block.
///
/// Closure bodies do **not** act as a stopping boundary so that captured
/// variables from enclosing function scopes are resolved correctly.
class NoUtcTimeFormatWithoutEmpresaHelperLint
    extends GeneratedSkippingDartLintRule {
  NoUtcTimeFormatWithoutEmpresaHelperLint({
    this.config = const NoUtcTimeFormatConfig(),
  }) : super(code: _code);

  final NoUtcTimeFormatConfig config;

  static const _code = LintCode(
    'no_utc_time_format_without_empresa_helper',
    'DateFormat time-pattern used without an approved empresa time helper. '
        'This can display UTC time instead of empresa local time.',
    correctionMessage:
        'Wrap the DateTime argument with an approved helper before formatting, '
        'e.g. DateFormat("HH:mm").format(empresaTimeService.toEmpresaLocalTime(timestamp)).',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final path = normalizeLintPath(resolver.path);
    if (!config.matchesPath(path)) return;

    // Phase 1: file-level pre-scan for formatter variable names only.
    // Pre-converted variable resolution is done inline in Phase 2 (scope-aware).
    final timeFormatVarNames = <String>{};
    context.registry.addCompilationUnit((CompilationUnit unit) {
      unit.accept(_TimeFormatVarCollector(timeFormatVarNames));
    });

    // Phase 2: check every .format() call.
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'format') return;
      if (node.argumentList.arguments.isEmpty) return;
      if (!_isTimeFormatTarget(node.target, timeFormatVarNames)) return;

      final arg = _unwrapArgument(node.argumentList.arguments.first);

      // 1. Direct approved-wrapper call: fmt.format(svc.toEmpresaLocalTime(ts))
      if (config.isApprovedWrapper(arg)) return;

      // 2. Pre-converted local variable resolved in lexical scope:
      //      final local = svc.toEmpresaLocalTime(ts); ... fmt.format(local)
      //      DateTime local; local = svc.toEmpresaLocalTime(ts); fmt.format(local)
      if (arg is SimpleIdentifier && _isPreConvertedInScope(arg.name, node)) {
        return;
      }

      // 3. UTC debug-context escape hatch (opt-in via allow_utc_debug_context).
      if (config.allowUtcDebugContext && _isInUtcStringContext(node)) return;

      reporter.atNode(node, _code);
    });
  }

  // ---------------------------------------------------------------------------
  // Phase 2 — target classification
  // ---------------------------------------------------------------------------

  bool _isTimeFormatTarget(Expression? target, Set<String> knownVarNames) {
    if (target == null) return false;

    if (target is InstanceCreationExpression) {
      return isDateFormatTimeInstance(target);
    }

    if (target is MethodInvocation) {
      if (isDateFormatTimeNamedConstructor(target)) return true;
      if (isDateFormatFunctionCall(target)) return true;
      return _nameContainsTimeSignal(target.methodName.name);
    }

    if (target is SimpleIdentifier) {
      return knownVarNames.contains(target.name) ||
          _nameContainsTimeSignal(target.name);
    }

    if (target is PrefixedIdentifier) {
      return knownVarNames.contains(target.identifier.name) ||
          _nameContainsTimeSignal(target.identifier.name) ||
          _nameContainsTimeSignal(target.prefix.name);
    }

    if (target is PropertyAccess) {
      return _nameContainsTimeSignal(target.propertyName.name);
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Phase 2 — scope-aware pre-converted variable resolution
  // ---------------------------------------------------------------------------

  /// Returns true when [varName] is definitively the result of an approved
  /// wrapper call, evaluated in the lexical scope chain that encloses
  /// [formatCallNode], walking upward through [Block] ancestors and stopping at
  /// function/method declaration boundaries.
  ///
  /// Note: closure (`FunctionExpression`) bodies are **not** treated as
  /// boundaries, so variables captured from an enclosing function scope are
  /// resolved correctly.
  bool _isPreConvertedInScope(String varName, AstNode formatCallNode) {
    AstNode? current = formatCallNode.parent;
    while (current != null) {
      if (current is Block) {
        final result = _resolveInBlock(varName, current, formatCallNode.offset);
        switch (result) {
          case _VarResolution.converted:
            return true;
          case _VarResolution.notConverted:
            return false;
          case _VarResolution.unknown:
            break; // not found in this block — walk to outer scope
        }
      }
      if (_isFunctionBoundary(current)) break;
      current = current.parent;
    }
    return false;
  }

  /// Scans [block] for the last statement that declares or assigns [varName]
  /// strictly before the statement containing [formatOffset].
  _VarResolution _resolveInBlock(
    String varName,
    Block block,
    int formatOffset,
  ) {
    // Identify which statement in this block directly (or transitively) contains
    // the format call, so we only consider statements that precede it.
    var containingIndex = -1;
    final stmts = block.statements;
    for (var i = 0; i < stmts.length; i++) {
      final s = stmts[i];
      if (s.offset <= formatOffset && formatOffset < s.end) {
        containingIndex = i;
        break;
      }
    }
    if (containingIndex < 0) return _VarResolution.unknown;

    // Find the LAST statement (before the containing one) that declares or
    // assigns varName — it represents the most recent "value" of the variable.
    Statement? lastRelevant;
    for (var i = 0; i < containingIndex; i++) {
      if (_declaresOrAssigns(varName, stmts[i])) lastRelevant = stmts[i];
    }
    if (lastRelevant == null) return _VarResolution.unknown;

    return _classifyStatement(varName, lastRelevant);
  }

  bool _declaresOrAssigns(String varName, Statement stmt) {
    if (stmt is VariableDeclarationStatement) {
      return stmt.variables.variables.any((d) => d.name.lexeme == varName);
    }
    if (stmt is ExpressionStatement) {
      final expr = stmt.expression;
      if (expr is AssignmentExpression) {
        final lhs = expr.leftHandSide;
        return lhs is SimpleIdentifier && lhs.name == varName;
      }
    }
    return false;
  }

  _VarResolution _classifyStatement(String varName, Statement stmt) {
    if (stmt is VariableDeclarationStatement) {
      final decl = stmt.variables.variables.firstWhere(
        (d) => d.name.lexeme == varName,
      );
      final init = decl.initializer;
      // Declared without initialiser — treat as not-converted (default value,
      // no approved wrapper used yet).
      if (init == null) return _VarResolution.notConverted;
      return config.isApprovedWrapper(init)
          ? _VarResolution.converted
          : _VarResolution.notConverted;
    }

    if (stmt is ExpressionStatement) {
      final assign = stmt.expression as AssignmentExpression;
      return config.isApprovedWrapper(assign.rightHandSide)
          ? _VarResolution.converted
          : _VarResolution.notConverted;
    }

    return _VarResolution.unknown;
  }

  /// Stops the upward scope walk at true function/method declaration nodes.
  /// [FunctionExpression] (closures) is intentionally excluded so variables
  /// captured from an enclosing scope can be resolved.
  bool _isFunctionBoundary(AstNode node) =>
      node is FunctionDeclaration || node is MethodDeclaration;

  // ---------------------------------------------------------------------------
  // Phase 2 — UTC debug-context detection
  // ---------------------------------------------------------------------------

  bool _isInUtcStringContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is StringInterpolation) {
        return current.elements.whereType<InterpolationString>().any(
          (s) => s.value.contains('UTC'),
        );
      }
      if (current is FunctionBody ||
          current is MethodDeclaration ||
          current is FunctionDeclaration) {
        return false;
      }
      current = current.parent;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  bool _nameContainsTimeSignal(String name) =>
      _splitWords(name).any(_timeSignalWords.contains);

  static const _timeSignalWords = {
    'time',
    'hour',
    'hora',
    'hm',
    'hms',
    'heure',
    'minute',
    'clock',
  };

  Set<String> _splitWords(String value) {
    final normalized = value.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    );
    return normalized
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
  }

  Expression _unwrapArgument(Argument expression) {
    // A named argument unwraps to its value; a positional one is itself.
    return expression.argumentExpression;
  }
}

// ---------------------------------------------------------------------------
// Scope-resolution result
// ---------------------------------------------------------------------------

enum _VarResolution {
  /// The variable was definitively assigned from an approved wrapper.
  converted,

  /// The variable was declared or assigned from a non-approved expression,
  /// or declared without initialisation.
  notConverted,

  /// The variable is not declared or directly assigned in this block —
  /// the caller should continue to the outer scope.
  unknown,
}

// ---------------------------------------------------------------------------
// Shared DateFormat-detection helpers
// ---------------------------------------------------------------------------

bool isTimeDateFormatExpr(Expression expr) {
  if (expr is InstanceCreationExpression) return isDateFormatTimeInstance(expr);
  if (expr is MethodInvocation) {
    if (isDateFormatTimeNamedConstructor(expr)) return true;
    if (isDateFormatFunctionCall(expr)) return true;
  }
  return false;
}

bool isDateFormatTimeInstance(InstanceCreationExpression node) {
  final typeName = node.constructorName.type.name.lexeme;
  if (typeName != 'DateFormat') return false;
  final args = node.argumentList.arguments;
  if (args.isEmpty) return false;
  final first = _unwrapExpr(args.first);
  if (first is StringLiteral) {
    final value = first.stringValue;
    return value != null && isTimeFormatString(value);
  }
  return false;
}

bool isDateFormatTimeNamedConstructor(MethodInvocation node) {
  final target = node.target;
  if (target is! SimpleIdentifier) return false;
  if (target.name != 'DateFormat') return false;
  return _timeNamedConstructors.contains(node.methodName.name);
}

bool isDateFormatFunctionCall(MethodInvocation node) {
  if (node.target != null) return false;
  if (node.methodName.name != 'DateFormat') return false;
  final args = node.argumentList.arguments;
  if (args.isEmpty) return false;
  final first = _unwrapExpr(args.first);
  if (first is StringLiteral) {
    final value = first.stringValue;
    return value != null && isTimeFormatString(value);
  }
  return false;
}

bool isTimeFormatString(String pattern) {
  final withoutQuotes = pattern.replaceAll(RegExp(r"'[^']*'"), '');
  return RegExp(r'[HhkKjJ]').hasMatch(withoutQuotes);
}

Expression _unwrapExpr(Argument expression) {
  // A named argument unwraps to its value; a positional one is itself.
  return expression.argumentExpression;
}

const _timeNamedConstructors = {
  'Hm',
  'Hms',
  'j',
  'jm',
  'jms',
  'jmv',
  'jmz',
  'jmsvz',
};

// ---------------------------------------------------------------------------
// Phase-1 collector — formatter variable names (file-level, order-independent)
// ---------------------------------------------------------------------------

/// Collects every variable initialised with a time-pattern DateFormat.
/// This is the only file-level set; pre-converted variable tracking is
/// done scope-locally in Phase 2.
class _TimeFormatVarCollector extends RecursiveAstVisitor<void> {
  _TimeFormatVarCollector(this._names);

  final Set<String> _names;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    super.visitVariableDeclaration(node);
    final init = node.initializer;
    if (init != null && isTimeDateFormatExpr(init)) {
      _names.add(node.name.lexeme);
    }
  }
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

class NoUtcTimeFormatConfig {
  const NoUtcTimeFormatConfig({
    this.includeGlobs = _defaultIncludes,
    this.excludeGlobs = _defaultExcludes,
    this.allowedWrappers = _defaultAllowedWrappers,
    this.allowUtcDebugContext = false,
  });

  static const _defaultIncludes = [
    '**/presentation/**',
    '**/screens/**',
    '**/widgets/**',
    '**/ui/**',
  ];

  static const _defaultExcludes = [
    '**/test/**',
    '**/tests/**',
    '**/*_test.dart',
  ];

  static const _defaultAllowedWrappers = [
    '*.toEmpresaLocalTime',
    'EmpresaDateTimeFormatter.*',
  ];

  final List<String> includeGlobs;
  final List<String> excludeGlobs;
  final List<String> allowedWrappers;

  /// When true, `.format()` calls inside a string interpolation that contains
  /// the literal `'UTC'` are silenced (diagnostic / debug context).
  final bool allowUtcDebugContext;

  bool matchesPath(String normalizedPath) {
    if (!matchesAnyGlob(normalizedPath, includeGlobs)) return false;
    if (excludeGlobs.isNotEmpty &&
        matchesAnyGlob(normalizedPath, excludeGlobs)) {
      return false;
    }
    return true;
  }

  bool isApprovedWrapper(Expression arg) {
    if (allowedWrappers.isEmpty) return false;
    if (arg is! MethodInvocation) return false;
    final candidates = _callCandidates(arg);
    return candidates.any(
      (candidate) => matchesAnyWildcard(candidate, allowedWrappers),
    );
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

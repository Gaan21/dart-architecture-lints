import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces top-level/routable Screen widgets to extend
/// a base contract class defined in `screens/base/`.
///
/// **Detection strategy (two-phase, per compilation unit)**:
///
/// Phase 1 — Shell-route collection:
///   Identifies GoRoute AST nodes that are children of StatefulShellBranch.
///   Two sub-patterns are supported within the same compilation unit:
///     A) Direct nesting: GoRoute inside StatefulShellBranch(routes:[GoRoute(...)])
///     B) Variable ref:   StatefulShellBranch(routes: _varName) where _varName
///        is a top-level list variable containing GoRoute instances in the
///        same file.
///   GoRoute nodes from cross-file variable references are not resolvable
///   via AST alone; those files are conservatively left unchecked.
///
/// Phase 2 — Route checking:
///   For every GoRoute/MaterialPageRoute NOT identified in Phase 1, inspects
///   the builder/pageBuilder expression for *Screen instantiations and
///   reports screens that do not extend a Base*Screen class.
///
/// **Activation**: No-op when no `screens/base/*.dart` file exists in the
/// project (the base-contract convention is not adopted).
///
/// **Extension map**: Built once per project root by regex-scanning lib/ for
///   `class XScreen extends Base*Screen` patterns.
///
/// **Hard-coded exceptions** (bootstrapping/gate screens exempt from the
/// contract): SplashScreen, LockScreen, AuthScreen, MainShellScreen,
///   AccountInactiveScreen (account-wall: full-block gate, no base AppBar)
class TopLevelScreensMustUseBaseContract extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [TopLevelScreensMustUseBaseContract].
  TopLevelScreensMustUseBaseContract() : super(code: _code);

  static const _exceptions = {
    'SplashScreen',
    'LockScreen',
    'AuthScreen',
    'MainShellScreen',
    'AccountInactiveScreen',
  };

  /// Cache: projectRoot → whether the project has any screens/base/ contracts.
  static final Map<String, bool> _projectHasBaseContractsCache = {};

  /// Cache: projectRoot → {screenClassName → extendsBaseContract}.
  /// Built once per project root by scanning lib/ for class declarations.
  static final Map<String, Map<String, bool>> _screenExtensionCache = {};

  static const _code = LintCode(
    'top_level_screens_must_use_base_contract',
    'Las pantallas enrutadas de nivel superior deben extender un contrato '
        'base (Base*Screen) de screens/base/ para garantizar comportamiento '
        'consistente (analytics, theming, lifecycle hooks).',
    correctionMessage:
        'Haz que esta pantalla extienda la clase base correspondiente.\n'
        'Ejemplo:\n'
        '  // En lib/.../screens/base/base_authenticated_screen.dart\n'
        '  abstract class BaseAuthenticatedScreen extends StatelessWidget {\n'
        '    const BaseAuthenticatedScreen({super.key});\n'
        '  }\n'
        '\n'
        '  // En tu pantalla\n'
        '  class ProfileScreen extends BaseAuthenticatedScreen {\n'
        '    const ProfileScreen({super.key});\n'
        '    @override\n'
        '    Widget build(BuildContext context) => ...;\n'
        '  }\n'
        '\n'
        'Si esta pantalla es tab de un StatefulShellRoute o una excepción '
        'justificada (SplashScreen, LockScreen, AuthScreen, MainShellScreen, '
        'AccountInactiveScreen), el lint no se aplica.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final projectRoot = _projectRoot(_normalizePath(resolver.uri.path));
    if (projectRoot == null) return;

    // Rule is inactive when the project has no screens/base/ contracts.
    if (!_projectHasBaseContracts(projectRoot)) return;

    context.registry.addCompilationUnit((CompilationUnit unit) {
      // Phase 1: determine which GoRoute nodes are shell-branch children.
      final shellOffsets = _collectShellBranchRouteOffsets(unit);

      // Phase 2: check non-shell route builders.
      final extMap = _getScreenExtensionMap(projectRoot);
      unit.accept(
        _RouteCheckerVisitor(
          shellOffsets: shellOffsets,
          extMap: extMap,
          exceptions: _exceptions,
          reporter: reporter,
          code: _code,
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Phase 1: shell-branch route collection
  // ---------------------------------------------------------------------------

  /// Returns the set of source offsets of GoRoute nodes that are children of
  /// any StatefulShellBranch in [unit], supporting two patterns:
  ///
  ///   A) Direct AST nesting:
  ///        StatefulShellBranch(routes: [GoRoute(...), ...])
  ///
  ///   B) Top-level variable reference (same file):
  ///        final _routes = [GoRoute(...), ...];
  ///        StatefulShellBranch(routes: _routes)
  static Set<int> _collectShellBranchRouteOffsets(CompilationUnit unit) {
    // Pre-scan: build map of top-level list variables that contain GoRoute
    // nodes.  This must run before StatefulShellBranch detection so that
    // variable references in any position are resolved correctly.
    final listVarGoRoutes = <String, List<int>>{};
    for (final decl in unit.declarations) {
      if (decl is TopLevelVariableDeclaration) {
        for (final v in decl.variables.variables) {
          if (v.initializer is ListLiteral) {
            final offsets = <int>[];
            _goRouteOffsetsFromList(v.initializer as ListLiteral, offsets);
            if (offsets.isNotEmpty) {
              listVarGoRoutes[v.name.lexeme] = offsets;
            }
          }
        }
      }
    }

    // Collect GoRoute offsets that appear inside StatefulShellBranch.routes.
    final shellOffsets = <int>{};
    unit.visitChildren(_ShellBranchFinder(listVarGoRoutes, shellOffsets));
    return shellOffsets;
  }

  static void _goRouteOffsetsFromList(ListLiteral list, List<int> out) {
    for (final element in list.elements) {
      if (element is InstanceCreationExpression &&
          element.constructorName.type.name.lexeme == 'GoRoute') {
        out.add(element.offset);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Filesystem helpers (cached)
  // ---------------------------------------------------------------------------

  /// Returns true if the project has at least one `.dart` file in a
  /// `screens/base/` directory (confirms the convention is adopted).
  bool _projectHasBaseContracts(String projectRoot) {
    return _projectHasBaseContractsCache.putIfAbsent(projectRoot, () {
      try {
        final libDir = Directory('$projectRoot/lib');
        if (!libDir.existsSync()) return false;
        for (final entity in libDir.listSync(recursive: true)) {
          if (entity is File) {
            final p = _normalizePath(entity.path);
            if (p.contains('/screens/base/') &&
                p.endsWith('.dart') &&
                !p.endsWith('.g.dart') &&
                !p.endsWith('.freezed.dart')) {
              return true;
            }
          }
        }
      } catch (_) {}
      return false;
    });
  }

  /// Builds (or returns cached) a map of `{screenClassName → extendsBase}`.
  ///
  /// Scans every `.dart` file in `lib/` once using regex:
  ///   - `class XScreen extends Base*Screen` → true
  ///   - `class XScreen extends OtherClass`  → false
  ///
  /// Screens not found at all are absent from the map (treated conservatively:
  /// not reported).
  Map<String, bool> _getScreenExtensionMap(String projectRoot) {
    return _screenExtensionCache.putIfAbsent(projectRoot, () {
      final map = <String, bool>{};

      final basePattern = RegExp(
        r'(?:abstract\s+)?class\s+(\w+Screen)\s+extends\s+(Base\w+Screen)',
      );
      final anyExtendsPattern = RegExp(
        r'(?:abstract\s+)?class\s+(\w+Screen)\s+extends\s+(\w+)',
      );

      try {
        final libDir = Directory('$projectRoot/lib');
        if (!libDir.existsSync()) return map;

        for (final entity in libDir.listSync(recursive: true)) {
          if (entity is! File) continue;
          final p = _normalizePath(entity.path);
          if (!p.endsWith('.dart')) continue;
          if (p.endsWith('.g.dart') ||
              p.endsWith('.freezed.dart') ||
              p.endsWith('.mocks.dart')) {
            continue;
          }

          final content = entity.readAsStringSync();

          // Mark screens that DO extend a Base*Screen.
          for (final m in basePattern.allMatches(content)) {
            map[m.group(1)!] = true;
          }

          // Mark screens that extend something else (only if not already true).
          for (final m in anyExtendsPattern.allMatches(content)) {
            final className = m.group(1)!;
            final superName = m.group(2)!;
            if (map.containsKey(className)) continue;
            if (!(superName.startsWith('Base') &&
                superName.endsWith('Screen'))) {
              map[className] = false;
            }
          }
        }
      } catch (_) {}

      return map;
    });
  }

  String? _projectRoot(String normalizedPath) {
    final libIdx = normalizedPath.indexOf('/lib/');
    if (libIdx != -1) return normalizedPath.substring(0, libIdx);
    final testIdx = normalizedPath.indexOf('/test/');
    if (testIdx != -1) return normalizedPath.substring(0, testIdx);
    return null;
  }

  String _normalizePath(String path) => path.replaceAll('\\', '/');
}

// ---------------------------------------------------------------------------
// _ShellBranchFinder
// Collects GoRoute offsets that are direct or variable-ref children of
// StatefulShellBranch(routes: ...).
// ---------------------------------------------------------------------------

class _ShellBranchFinder extends RecursiveAstVisitor<void> {
  final Map<String, List<int>> _listVarGoRoutes;
  final Set<int> shellRouteOffsets;

  _ShellBranchFinder(this._listVarGoRoutes, this.shellRouteOffsets);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'StatefulShellBranch') {
      _processShellBranch(node);
    }
    super.visitInstanceCreationExpression(node);
  }

  void _processShellBranch(InstanceCreationExpression node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedArgument && arg.name.lexeme == 'routes') {
        _collectFrom(arg.argumentExpression);
      }
    }
  }

  void _collectFrom(Expression expr) {
    if (expr is ListLiteral) {
      // Pattern A: routes: [GoRoute(...), ...]
      for (final element in expr.elements) {
        if (element is InstanceCreationExpression &&
            element.constructorName.type.name.lexeme == 'GoRoute') {
          shellRouteOffsets.add(element.offset);
        }
      }
    } else if (expr is SimpleIdentifier) {
      // Pattern B: routes: _varName  (top-level list variable in same file)
      final routes = _listVarGoRoutes[expr.name];
      if (routes != null) shellRouteOffsets.addAll(routes);
    }
  }
}

// ---------------------------------------------------------------------------
// _RouteCheckerVisitor
// Visits GoRoute / MaterialPageRoute nodes that are NOT shell-branch children,
// and reports *Screen instances inside their builders that lack Base*Screen.
// ---------------------------------------------------------------------------

class _RouteCheckerVisitor extends RecursiveAstVisitor<void> {
  final Set<int> shellOffsets;
  final Map<String, bool> extMap;
  final Set<String> exceptions;
  final DiagnosticReporter reporter;
  final LintCode code;

  _RouteCheckerVisitor({
    required this.shellOffsets,
    required this.extMap,
    required this.exceptions,
    required this.reporter,
    required this.code,
  });

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);

    final typeName = node.constructorName.type.name.lexeme;
    if (typeName != 'GoRoute' && typeName != 'MaterialPageRoute') return;

    // Skip shell-branch children identified in Phase 1 (offset-based).
    if (shellOffsets.contains(node.offset)) return;

    // Belt-and-suspenders: also skip via direct AST parent-chain check.
    // This handles any direct-nesting patterns not caught by Phase 1.
    if (_isInsideStatefulShellBranch(node)) return;

    final builderExpr = _findBuilderArg(node);
    if (builderExpr == null) return;

    final screens = <(String name, AstNode site)>[];
    builderExpr.visitChildren(_ScreenCollector(screens));

    for (final (name, site) in screens) {
      if (exceptions.contains(name)) continue;

      // true  → confirmed extends Base*Screen → ok
      // false → confirmed does NOT          → report
      // null  → not found in lib/ (external/generated) → skip conservatively
      final extendsBase = extMap[name];
      if (extendsBase == null || extendsBase) continue;

      reporter.atNode(site, code);
    }
  }

  /// Walks the parent chain looking for a [StatefulShellBranch] ancestor.
  bool _isInsideStatefulShellBranch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression &&
          current.constructorName.type.name.lexeme == 'StatefulShellBranch') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Returns the expression value of the `builder` or `pageBuilder` named arg.
  Expression? _findBuilderArg(InstanceCreationExpression node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedArgument) {
        final label = arg.name.lexeme;
        if (label == 'builder' || label == 'pageBuilder') {
          return arg.argumentExpression;
        }
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// _ScreenCollector
// Collects *Screen instantiations (and tear-offs) inside a builder expression.
// ---------------------------------------------------------------------------

class _ScreenCollector extends RecursiveAstVisitor<void> {
  final List<(String name, AstNode site)> screens;

  _ScreenCollector(this.screens);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    final name = node.constructorName.type.name.lexeme;
    if (name.endsWith('Screen') && !name.startsWith('_')) {
      screens.add((name, node));
    }
  }

  /// Also handles constructor tear-offs: `builder: ProfileScreen.new`
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    super.visitPrefixedIdentifier(node);
    if (node.identifier.name == 'new' &&
        node.prefix.name.endsWith('Screen') &&
        !node.prefix.name.startsWith('_')) {
      screens.add((node.prefix.name, node));
    }
  }
}

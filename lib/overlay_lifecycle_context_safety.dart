import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Detects two overlay lifecycle hazards that are NOT covered by
/// `use_build_context_synchronously` (because there is no `await` between the
/// capture and the use — the unsafe access happens in a later, framework-driven
/// rebuild of the overlay builder):
///
/// - **A** — a lifecycle resource (TextEditingController/FocusNode/…) declared as
///   a local in the caller and captured by a dialog/sheet `builder:` closure.
///   The caller cannot dispose it safely across the overlay lifecycle, and the
///   overlay's FocusNode may touch it after disposal
///   ("A TextEditingController was used after being disposed").
/// - **B** — an inherited-widget lookup (`Theme.of`, `AppLocalizations.of`,
///   `context.read`, …) performed inside an overlay `builder:` closure using a
///   BuildContext captured from the CALLER instead of the builder's own context
///   parameter. When the caller widget deactivates while the overlay is open,
///   the lookup runs on a defunct element
///   ("Looking up a deactivated widget's ancestor is unsafe").
///
/// The analysis is fully AST/element scoped: it only inspects code INSIDE the
/// overlay builder closure, so ordinary `build(context)` methods elsewhere in
/// the file are never flagged.
class OverlayLifecycleContextSafetyLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [OverlayLifecycleContextSafetyLint].
  OverlayLifecycleContextSafetyLint() : super(code: _code);

  /// Top-level overlay functions whose `builder:` closure is scanned.
  static const _overlayFunctions = <String>{
    'showDialog',
    'showModalBottomSheet',
    'showGeneralDialog',
    'showCupertinoDialog',
    'showCupertinoModalPopup',
    'showDatePicker',
    'showTimePicker',
  };

  /// Route constructors whose `builder:` closure is scanned (same hazard class).
  static const _overlayRouteClasses = <String>{
    'MaterialPageRoute',
    'CupertinoPageRoute',
    'PageRouteBuilder',
    'DialogRoute',
    'RawDialogRoute',
    'ModalBottomSheetRoute',
    'CupertinoModalPopupRoute',
  };

  /// Lifecycle resource types that must be owned by a StatefulWidget's State.
  static const _controllerTypes = <String>{
    'TextEditingController',
    'FocusNode',
    'AnimationController',
    'ScrollController',
    'PageController',
    'TabController',
  };

  /// Classes exposing inherited state via a static `of`/`maybeOf`/`*Of` lookup.
  static const _inheritedAccessorClasses = <String>{
    'Theme',
    'MediaQuery',
    'Localizations',
    'Directionality',
    'DefaultTextStyle',
    'ScaffoldMessenger',
    'Navigator',
    'Router',
    'GoRouter',
    'Provider',
    'Form',
    'Focus',
    'FocusScope',
    'AppLocalizations',
    'MaterialLocalizations',
    'CupertinoLocalizations',
    'CupertinoTheme',
    'Overlay',
    'Actions',
    'Shortcuts',
    'DefaultTabController',
    'PrimaryScrollController',
  };

  /// BuildContext extension lookups (`context.read<T>()`, etc.).
  static const _contextExtensionLookups = <String>{'read', 'watch', 'select'};

  static const _code = LintCode(
    'overlay_lifecycle_context_safety',
    'Overlay lifecycle/context hazard: dialog/sheet builders must not capture a caller-owned controller or use a caller BuildContext for inherited lookups (use a dedicated StatefulWidget and the builder\'s own context).',
    correctionMessage: 'Move the controller into a StatefulWidget rendered by the overlay and dispose it in State.dispose(); resolve inherited values before opening the overlay or use the builder context parameter.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_overlayFunctions.contains(node.methodName.name)) return;
      _analyzeOverlay(node, node.argumentList, reporter);
    });

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final typeName = node.constructorName.type.name.lexeme;
      if (!_overlayRouteClasses.contains(typeName)) return;
      _analyzeOverlay(node, node.argumentList, reporter);
    });
  }

  void _analyzeOverlay(
    AstNode overlayNode,
    ArgumentList argumentList,
    DiagnosticReporter reporter,
  ) {
    final builder = _builderClosure(argumentList);
    if (builder == null) return;

    final declaredInBuilder = _DeclaredElementCollector();
    builder.accept(declaredInBuilder);

    // Pattern B: inherited lookups using a captured (non-builder) context.
    builder.body.accept(
      _CapturedContextLookupVisitor(declaredInBuilder.elements, reporter),
    );

    // Pattern A: caller-owned local controllers captured by the builder.
    _reportCapturedControllers(overlayNode, builder, reporter);
  }

  FunctionExpression? _builderClosure(ArgumentList argumentList) {
    for (final argument in argumentList.arguments) {
      if (argument is NamedArgument && argument.name.lexeme == 'builder') {
        final expression = argument.argumentExpression;
        if (expression is FunctionExpression) return expression;
      }
    }
    return null;
  }

  void _reportCapturedControllers(
    AstNode overlayNode,
    FunctionExpression builder,
    DiagnosticReporter reporter,
  ) {
    final enclosingBody = overlayNode.thisOrAncestorOfType<FunctionBody>();
    if (enclosingBody == null) return;

    final controllerCollector = _LocalControllerCollector(
      builder.offset,
      builder.end,
      _controllerTypes,
    );
    enclosingBody.accept(controllerCollector);
    if (controllerCollector.controllers.isEmpty) return;

    final referencedInBuilder = _ReferencedElementCollector();
    builder.body.accept(referencedInBuilder);

    for (final controller in controllerCollector.controllers) {
      if (referencedInBuilder.elements.contains(controller.element)) {
        reporter.atNode(controller.declaration, _code);
      }
    }
  }
}

/// Collects the canonical elements DECLARED inside a builder closure
/// (its parameters and any local variables/parameters of nested functions).
class _DeclaredElementCollector extends RecursiveAstVisitor<void> {
  final Set<Object> elements = <Object>{};

  void _add(Object? element) {
    if (element != null) elements.add(element);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _add(node.declaredFragment?.element);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitRegularFormalParameter(RegularFormalParameter node) {
    _add(node.declaredFragment?.element);
    super.visitRegularFormalParameter(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    _add(node.declaredFragment?.element);
    super.visitFieldFormalParameter(node);
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    _add(node.declaredFragment?.element);
    super.visitSuperFormalParameter(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    _add(node.declaredFragment?.element);
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _add(node.declaredFragment?.element);
    super.visitFunctionDeclaration(node);
  }
}

/// Reports inherited-widget lookups inside a builder closure that use a
/// BuildContext whose element was NOT declared inside that closure (captured).
class _CapturedContextLookupVisitor extends RecursiveAstVisitor<void> {
  _CapturedContextLookupVisitor(this._declaredInBuilder, this._reporter);

  final Set<Object> _declaredInBuilder;
  final DiagnosticReporter _reporter;

  static const _accessorClasses =
      OverlayLifecycleContextSafetyLint._inheritedAccessorClasses;
  static const _extensionLookups =
      OverlayLifecycleContextSafetyLint._contextExtensionLookups;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final contextIdentifier = _capturedContextIdentifier(node);
    if (contextIdentifier != null) {
      final element = contextIdentifier.element;
      if (element != null && !_declaredInBuilder.contains(element)) {
        _reporter.atNode(node, OverlayLifecycleContextSafetyLint._code);
      }
    }
    super.visitMethodInvocation(node);
  }

  /// Returns the BuildContext identifier used by an inherited lookup, or null.
  SimpleIdentifier? _capturedContextIdentifier(MethodInvocation node) {
    final target = node.target;
    final methodName = node.methodName.name;

    // B1: `Theme.of(ctx)`, `AppLocalizations.of(ctx)`, `MediaQuery.paddingOf(ctx)`.
    if (target is SimpleIdentifier &&
        _accessorClasses.contains(target.name) &&
        (methodName == 'of' ||
            methodName == 'maybeOf' ||
            methodName.endsWith('Of'))) {
      final arguments = node.argumentList.arguments;
      if (arguments.isNotEmpty) {
        final first = arguments.first;
        if (first is SimpleIdentifier) return first;
      }
    }

    // B2: `context.read<T>()` / `.watch<T>()` / `.select<T>()`.
    if (target is SimpleIdentifier &&
        _extensionLookups.contains(methodName) &&
        _isBuildContext(target.staticType)) {
      return target;
    }

    return null;
  }

  bool _isBuildContext(DartType? type) {
    if (type == null) return false;
    return type.getDisplayString().replaceAll('?', '') == 'BuildContext';
  }
}

/// Collects local controller declarations within a function body, excluding any
/// declared inside the overlay builder closure (offset range).
class _LocalControllerCollector extends RecursiveAstVisitor<void> {
  _LocalControllerCollector(
    this._builderStart,
    this._builderEnd,
    this._controllerTypes,
  );

  final int _builderStart;
  final int _builderEnd;
  final Set<String> _controllerTypes;
  final List<_ControllerDeclaration> controllers = <_ControllerDeclaration>[];

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final isInsideBuilder =
        node.offset >= _builderStart && node.offset < _builderEnd;
    if (!isInsideBuilder) {
      final element = node.declaredFragment?.element;
      final type = element?.type;
      if (type is InterfaceType &&
          _controllerTypes.contains(type.element.displayName) &&
          element != null) {
        controllers.add(_ControllerDeclaration(node, element));
      }
    }
    super.visitVariableDeclaration(node);
  }
}

/// Collects every canonical element referenced within a subtree.
class _ReferencedElementCollector extends RecursiveAstVisitor<void> {
  final Set<Object> elements = <Object>{};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element != null) elements.add(element);
    super.visitSimpleIdentifier(node);
  }
}

class _ControllerDeclaration {
  const _ControllerDeclaration(this.declaration, this.element);

  final VariableDeclaration declaration;
  final Object element;
}

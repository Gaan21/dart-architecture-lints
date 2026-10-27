import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Per-file node callbacks registered by a rule before the file is walked.
///
/// Callbacks run in registration order, in a single pre-order walk of the
/// compilation unit; a callback for an abstract node type (for example
/// [StringLiteral]) runs for every subtype, after the callbacks of the more
/// specific type.
class RuleNodeRegistry {
  final _callbacks = <Type, List<void Function(Never)>>{};

  void _add<T extends AstNode>(void Function(T node) callback) =>
      (_callbacks[T] ??= []).add(callback);

  void addArgumentList(void Function(ArgumentList node) callback) =>
      _add(callback);
  void addBinaryExpression(void Function(BinaryExpression node) callback) =>
      _add(callback);
  void addClassDeclaration(void Function(ClassDeclaration node) callback) =>
      _add(callback);
  void addCompilationUnit(void Function(CompilationUnit node) callback) =>
      _add(callback);
  void addFieldDeclaration(void Function(FieldDeclaration node) callback) =>
      _add(callback);
  void addForElement(void Function(ForElement node) callback) => _add(callback);
  void addForStatement(void Function(ForStatement node) callback) =>
      _add(callback);
  void addFunctionDeclaration(
    void Function(FunctionDeclaration node) callback,
  ) => _add(callback);
  void addFunctionExpressionInvocation(
    void Function(FunctionExpressionInvocation node) callback,
  ) => _add(callback);
  void addIfStatement(void Function(IfStatement node) callback) =>
      _add(callback);
  void addImportDirective(void Function(ImportDirective node) callback) =>
      _add(callback);
  void addInstanceCreationExpression(
    void Function(InstanceCreationExpression node) callback,
  ) => _add(callback);
  void addMethodDeclaration(void Function(MethodDeclaration node) callback) =>
      _add(callback);
  void addMethodInvocation(void Function(MethodInvocation node) callback) =>
      _add(callback);
  void addMixinDeclaration(void Function(MixinDeclaration node) callback) =>
      _add(callback);
  void addPostfixExpression(void Function(PostfixExpression node) callback) =>
      _add(callback);
  void addRegularFormalParameter(
    void Function(RegularFormalParameter node) callback,
  ) => _add(callback);
  void addStringInterpolation(
    void Function(StringInterpolation node) callback,
  ) => _add(callback);
  void addStringLiteral(void Function(StringLiteral node) callback) =>
      _add(callback);
  void addTopLevelVariableDeclaration(
    void Function(TopLevelVariableDeclaration node) callback,
  ) => _add(callback);
  void addVariableDeclarationList(
    void Function(VariableDeclarationList node) callback,
  ) => _add(callback);
  void addVariableDeclarationStatement(
    void Function(VariableDeclarationStatement node) callback,
  ) => _add(callback);

  /// Walks [unit] once, running the registered callbacks.
  void run(CompilationUnit unit) {
    if (_callbacks.isNotEmpty) unit.accept(_Dispatcher(this));
  }

  void _run<T extends AstNode>(T node) {
    final callbacks = _callbacks[T];
    if (callbacks == null) return;
    for (final callback in callbacks) {
      try {
        (callback as void Function(T))(node);
      } catch (exception, stackTrace) {
        // A failing callback must not stop the walk for the rest of the file.
        Zone.current.handleUncaughtError(exception, stackTrace);
      }
    }
  }
}

/// Generalizing walk: each visit runs the node's callbacks, then the more
/// general visit method, which eventually visits the children.
class _Dispatcher extends GeneralizingAstVisitor<void> {
  _Dispatcher(this._registry);

  final RuleNodeRegistry _registry;

  @override
  void visitArgumentList(ArgumentList node) {
    _registry._run(node);
    super.visitArgumentList(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    _registry._run(node);
    super.visitBinaryExpression(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _registry._run(node);
    super.visitClassDeclaration(node);
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    _registry._run(node);
    super.visitCompilationUnit(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    _registry._run(node);
    super.visitFieldDeclaration(node);
  }

  @override
  void visitForElement(ForElement node) {
    _registry._run(node);
    super.visitForElement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    _registry._run(node);
    super.visitForStatement(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _registry._run(node);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    _registry._run(node);
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    _registry._run(node);
    super.visitIfStatement(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    _registry._run(node);
    super.visitImportDirective(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _registry._run(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _registry._run(node);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _registry._run(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _registry._run(node);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    _registry._run(node);
    super.visitPostfixExpression(node);
  }

  @override
  void visitRegularFormalParameter(RegularFormalParameter node) {
    _registry._run(node);
    super.visitRegularFormalParameter(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    _registry._run(node);
    super.visitStringInterpolation(node);
  }

  @override
  void visitStringLiteral(StringLiteral node) {
    _registry._run(node);
    super.visitStringLiteral(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _registry._run(node);
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    _registry._run(node);
    super.visitVariableDeclarationList(node);
  }

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    _registry._run(node);
    super.visitVariableDeclarationStatement(node);
  }
}

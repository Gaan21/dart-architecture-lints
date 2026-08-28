import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that detects business logic patterns in Widgets.
/// Enforces MVVM separation: Widgets only render, ViewModels/UiState handle logic.
class NoBusinessLogicInWidgets extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoBusinessLogicInWidgets].
  const NoBusinessLogicInWidgets() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Mueve el filtrado/cálculo a tu ViewModel o UiState y expone datos listos para renderizar.\n'
        'Ejemplo:\n'
        '  // ❌ MAL: Filtrado en Widget\n'
        '  class _Content extends StatelessWidget {\n'
        '    @override\n'
        '    Widget build(BuildContext context) {\n'
        '      final vm = context.watch<OrdersViewModel>();\n'
        '      final filtered = vm.orders.where((o) => o.isActive).toList();\n'
        '      return OrdersList(filtered);\n'
        '    }\n'
        '  }\n\n'
        '  // ✅ BIEN: ViewModel expone datos\n'
        '  class OrdersViewModel extends BaseViewModel {\n'
        '    List<Order> get filteredOrders => _orders.where((o) => _matchesQuery(o)).toList();\n'
        '  }\n\n'
        '  class _Content extends StatelessWidget {\n'
        '    @override\n'
        '    Widget build(BuildContext context) {\n'
        '      final filtered = context.select((OrdersViewModel vm) => vm.filteredOrders);\n'
        '      return OrdersList(filtered);\n'
        '    }\n'
        '  }',
    name: 'no_business_logic_in_widgets',
    problemMessage:
        'No mezcles lógica de negocio en Widgets; delega en ViewModel o UiState. Widgets solo deben renderizar datos ya procesados.',
  );

  /// Executes the lint rule to detect business logic in Widgets.
  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final uri = resolver.source.uri;
    final path = uri.path;

    // Solo aplicar en presentation/screens/ y presentation/widgets/
    if (!path.contains('/presentation/screens/') &&
        !path.contains('/presentation/widgets/')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Solo verificar Widgets (extends StatelessWidget, StatefulWidget)
      if (!_isWidgetClass(node)) {
        return;
      }

      // Verificar métodos build, callbacks, y initState
      for (final member in node.members) {
        if (member is MethodDeclaration) {
          _checkMethod(member, reporter);
        }
      }
    });
  }

  /// Checks if the class extends StatelessWidget or StatefulWidget.
  bool _isWidgetClass(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) return false;

    final superclass = extendsClause.superclass;
    final superclassName = superclass.name.lexeme;
    return superclassName == 'StatelessWidget' ||
        superclassName == 'StatefulWidget' ||
        superclassName == 'State';
  }

  /// Checks if a method contains business logic patterns.
  void _checkMethod(MethodDeclaration method, DiagnosticReporter reporter) {
    final methodName = method.name.lexeme;

    // Solo verificar build, initState, y callbacks relevantes
    if (methodName != 'build' &&
        methodName != 'initState' &&
        !methodName.startsWith('_on')) {
      return;
    }

    final body = method.body;
    if (body is! BlockFunctionBody) return;

    // Visitar el AST del método buscando patrones de lógica de negocio
    final visitor = _BusinessLogicVisitor(reporter, _code);
    body.visitChildren(visitor);
  }
}

/// AST Visitor que detecta patrones de lógica de negocio.
class _BusinessLogicVisitor extends RecursiveAstVisitor<void> {
  final DiagnosticReporter reporter;
  final LintCode code;

  _BusinessLogicVisitor(this.reporter, this.code);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);

    final typeName = node.constructorName.type.name.lexeme;

    // Detectar instanciación directa de UseCases/Repositories en Widgets
    if (typeName.endsWith('UseCase') ||
        typeName.endsWith('Repository') ||
        typeName.endsWith('RepositoryImpl')) {
      reporter.atNode(node, code);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    final methodName = node.methodName.name;

    // Detectar patrones de filtrado/transformación compleja
    // where, map, fold con múltiples condiciones (heurística: línea larga)
    if (methodName == 'where' || methodName == 'fold' || methodName == 'map') {
      final arguments = node.argumentList.arguments;

      // Para fold, el closure está en el segundo argumento; para where/map, en el primero
      final closureArg = methodName == 'fold' && arguments.length >= 2
          ? arguments[1]
          : (arguments.isNotEmpty ? arguments.first : null);

      if (closureArg != null && closureArg is FunctionExpression) {
        final closureCode = closureArg.toSource();
        // Si el closure es complejo (más de 60 caracteres con >= 2 operadores), probablemente es lógica de negocio
        if (closureCode.length > 60 &&
            _containsMultipleConditions(closureCode)) {
          reporter.atNode(node, code);
        }
      }
    }

    // Detectar context.read<ViewModel>().useCase.execute() o vm.useCase.execute() desde Widgets
    if (methodName == 'execute') {
      final target = node.target;
      String? propertyName;

      // Caso 1: PropertyAccess (ej: context.read<VM>().useCase)
      if (target is PropertyAccess) {
        propertyName = target.propertyName.name;
      }
      // Caso 2: PrefixedIdentifier (ej: vm.useCase donde vm es variable local)
      else if (target is PrefixedIdentifier) {
        propertyName = target.identifier.name;
      }

      if (propertyName != null &&
          (propertyName.endsWith('UseCase') || propertyName.endsWith('useCase'))) {
        reporter.atNode(node, code);
      }
    }
  }

  /// Heurística: Detecta múltiples condiciones (&&, ||, >=2 operadores)
  bool _containsMultipleConditions(String code) {
    final andCount = '&&'.allMatches(code).length;
    final orCount = '||'.allMatches(code).length;
    return (andCount + orCount) >= 2;
  }
}

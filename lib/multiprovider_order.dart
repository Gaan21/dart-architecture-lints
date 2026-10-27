import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Ensures MultiProvider declares UiState providers before ViewModel providers.
class MultiProviderOrderLint extends GeneratedSkippingDartLintRule {
  /// Creates a new instance of the lint rule.
  MultiProviderOrderLint() : super(code: _code);

  static const _code = LintCode(
    'multiprovider_order',
    'Declare UiState providers before ViewModel providers so dependencies are available when the ViewModel initializes.',
    correctionMessage: 'Move UiState providers (classes ending in UiState) before ViewModel providers (classes ending in ViewModel) inside the MultiProvider list.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!_isMultiProvider(node)) return;

      final providersList = _providersList(node.argumentList);
      if (providersList == null) return;

      final entries = _classifyProviders(providersList);
      if (entries.isEmpty) return;

      final offending = _firstOutOfOrder(entries);
      if (offending == null) return;

      reporter.atNode(offending.node, _code);
    });
  }

  bool _isMultiProvider(InstanceCreationExpression node) {
    final type = node.constructorName.type;
    final name = _namedTypeToName(type);
    return name == 'MultiProvider';
  }

  ListLiteral? _providersList(ArgumentList argumentList) {
    for (final argument in argumentList.arguments) {
      if (argument is NamedArgument && argument.name.lexeme == 'providers') {
        final expression = argument.argumentExpression;
        if (expression is ListLiteral &&
            !expression.elements.any((element) => element is SpreadElement)) {
          return expression;
        }
        return null;
      }
    }
    return null;
  }

  List<_ProviderEntry> _classifyProviders(ListLiteral providers) {
    final entries = <_ProviderEntry>[];

    for (final element in providers.elements) {
      if (element is! Expression) continue;
      if (element is! InstanceCreationExpression) continue;

      final role = _detectRole(element);
      if (role == _ProviderRole.other) continue;

      entries.add(_ProviderEntry(node: element, role: role));
    }

    return entries;
  }

  _ProviderRole _detectRole(InstanceCreationExpression providerExpression) {
    final typeArgs = providerExpression.constructorName.type.typeArguments;
    if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
      final firstArg = typeArgs.arguments.first;
      final typeName = _typeAnnotationName(firstArg);
      final role = _roleFromName(typeName);
      if (role != _ProviderRole.other) {
        return role;
      }
    }

    for (final argument in providerExpression.argumentList.arguments) {
      if (argument is NamedArgument && argument.name.lexeme == 'create') {
        final role = _roleFromCreateExpression(argument.argumentExpression);
        if (role != _ProviderRole.other) {
          return role;
        }
      }
    }

    return _ProviderRole.other;
  }

  _ProviderRole _roleFromCreateExpression(Expression expression) {
    if (expression is FunctionExpression) {
      final body = expression.body;
      if (body is ExpressionFunctionBody) {
        return _roleFromExpression(body.expression);
      }
      if (body is BlockFunctionBody) {
        final finder = _ReturnFinder();
        body.block.visitChildren(finder);
        return _roleFromExpression(finder.lastReturnExpression);
      }
    }
    return _ProviderRole.other;
  }

  _ProviderRole _roleFromExpression(Expression? expression) {
    if (expression is InstanceCreationExpression) {
      final name = _typeAnnotationName(expression.constructorName.type);
      return _roleFromName(name);
    }
    if (expression is Identifier) {
      return _roleFromName(_identifierName(expression));
    }
    return _ProviderRole.other;
  }

  _ProviderRole _roleFromName(String? name) {
    if (name == null) return _ProviderRole.other;
    if (name.endsWith('UiState')) return _ProviderRole.uiState;
    if (name.endsWith('ViewModel')) return _ProviderRole.viewModel;
    return _ProviderRole.other;
  }

  _ProviderEntry? _firstOutOfOrder(List<_ProviderEntry> entries) {
    var seenViewModel = false;
    for (final entry in entries) {
      if (entry.role == _ProviderRole.viewModel) {
        seenViewModel = true;
        continue;
      }
      if (entry.role == _ProviderRole.uiState && seenViewModel) {
        return entry;
      }
    }
    return null;
  }
}

enum _ProviderRole { uiState, viewModel, other }

class _ProviderEntry {
  const _ProviderEntry({required this.node, required this.role});

  final InstanceCreationExpression node;
  final _ProviderRole role;
}

class _ReturnFinder extends RecursiveAstVisitor<void> {
  Expression? lastReturnExpression;

  @override
  void visitReturnStatement(ReturnStatement node) {
    lastReturnExpression = node.expression;
    super.visitReturnStatement(node);
  }
}

String? _typeAnnotationName(TypeAnnotation annotation) {
  if (annotation is NamedType) {
    return _namedTypeToName(annotation);
  }
  return null;
}

String? _namedTypeToName(NamedType type) {
  final resolved = type.type;
  if (resolved != null) {
    return resolved.getDisplayString();
  }
  return type.name.lexeme;
}

String? _identifierName(Identifier identifier) {
  if (identifier is SimpleIdentifier) return identifier.name;
  if (identifier is PrefixedIdentifier) return identifier.identifier.name;
  return null;
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import 'generated_skipping_dart_lint_rule.dart';

/// How a member's return type relates to the Result outcome contract.
enum ResultReturnShape {
  /// `Result`, or `Future`/`FutureOr`/`Stream` of `Result` (aliases resolved).
  result,

  /// `void`, or `Future`/`FutureOr`/`Stream` of `void`.
  voidLike,

  /// A synchronous non-Result value.
  syncValue,

  /// A `Future`/`FutureOr`/`Stream` of a non-Result value.
  asyncValue,

  /// No annotation and no inherited/declared type to classify.
  unknown,
}

/// Classifies [method] by its resolved return type, including typedef aliases
/// and types inherited by unannotated overrides. Falls back to the annotation
/// spelling only when the type is unresolved. `Result` is matched by class
/// name; this establishes a signature shape, not failure semantics.
ResultReturnShape resultReturnShape(MethodDeclaration method) {
  final annotation = method.returnType;
  final type = method.declaredFragment?.element.returnType;
  if (type == null || type is InvalidType) {
    return annotation == null
        ? ResultReturnShape.unknown
        : _syntactic(annotation);
  }
  // Unannotated non-overrides infer dynamic; preserve the former skip.
  if (annotation == null && type is DynamicType) {
    return ResultReturnShape.unknown;
  }
  if (type is VoidType) return ResultReturnShape.voidLike;
  if (type is InterfaceType &&
      (type.isDartAsyncFuture ||
          type.isDartAsyncFutureOr ||
          type.isDartAsyncStream)) {
    final argument = type.typeArguments.isEmpty
        ? null
        : type.typeArguments.first;
    if (argument is VoidType) return ResultReturnShape.voidLike;
    return _isResult(argument)
        ? ResultReturnShape.result
        : ResultReturnShape.asyncValue;
  }
  return _isResult(type)
      ? ResultReturnShape.result
      : ResultReturnShape.syncValue;
}

bool _isResult(DartType? type) =>
    type is InterfaceType && type.element.name == 'Result';

const _wrappers = {'Future', 'FutureOr', 'Stream'};

ResultReturnShape _syntactic(TypeAnnotation annotation) {
  if (annotation is! NamedType) return ResultReturnShape.syncValue;
  final name = annotation.name.lexeme;
  if (name == 'void') return ResultReturnShape.voidLike;
  if (name == 'Result') return ResultReturnShape.result;
  if (!_wrappers.contains(name)) return ResultReturnShape.syncValue;
  final arguments = annotation.typeArguments?.arguments;
  final first = arguments == null || arguments.isEmpty ? null : arguments.first;
  if (first is NamedType) {
    if (first.name.lexeme == 'void') return ResultReturnShape.voidLike;
    if (first.name.lexeme == 'Result') return ResultReturnShape.result;
  }
  return ResultReturnShape.asyncValue;
}

/// Shared member filter for the repository and data-source Result rules.
///
/// Synchronous getters and private members may return values directly.
/// Asynchronous getters remain operations: getter syntax does not establish
/// infallibility. Setters, operators `==`, `toString`, `noSuchMethod` and
/// void-like returns are excluded. Returns true when [method] must be reported.
bool violatesResultReturn(
  MethodDeclaration method, {
  required bool checkAbstract,
}) {
  final name = method.name.lexeme;
  if (name.startsWith('_') || method.isSetter) return false;
  if (!checkAbstract && isAbstractMethod(method)) return false;
  if (const {'toString', 'noSuchMethod', 'hashCode'}.contains(name)) {
    return false;
  }
  if (method.isOperator && name == '==') return false;
  final shape = resultReturnShape(method);
  return switch (shape) {
    ResultReturnShape.result ||
    ResultReturnShape.voidLike ||
    ResultReturnShape.unknown => false,
    ResultReturnShape.syncValue => !method.isGetter,
    ResultReturnShape.asyncValue => true,
  };
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prevents serialization logic in domain entities.
/// Serialization (fromJson/toJson) should only exist in data layer Models.
class NoSerializationInEntities extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoSerializationInEntities].
  const NoSerializationInEntities() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Crea un Model correspondiente en lib/data/models/ con @freezed y métodos de serialización. '
        'Usa Mappers para convertir entre Model y Entity.\n'
        'Ejemplo:\n'
        '  // lib/data/models/user_model.dart\n'
        '  @freezed\n'
        '  class UserModel with _\$UserModel {\n'
        '    const factory UserModel({required String id}) = _UserModel;\n'
        '    factory UserModel.fromJson(Map<String, dynamic> json) => _\$UserModelFromJson(json);\n'
        '  }',
    name: 'no_serialization_in_entities',
    problemMessage:
        'Las entidades de domain no deben tener métodos de serialización (fromJson/toJson). '
        'La serialización pertenece a la capa data (Models).',
  );

  /// Executes the lint rule to detect serialization in domain entities.
  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final uri = resolver.source.uri;
    final path = uri.path;

    // Solo aplicar en domain/entities/ y domain/value_objects/
    if (!path.contains('/domain/entities/') &&
        !path.contains('/domain/value_objects/')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Verificar anotaciones @JsonSerializable o @JsonKey
      for (final annotation in node.metadata) {
        final name = annotation.name.name;
        if (name == 'JsonSerializable' ||
            name == 'JsonKey' ||
            name == 'jsonSerializable') {
          reporter.atNode(
            annotation,
            _code,
          );
        }
      }

      // Verificar métodos fromJson/toJson
      for (final member in node.members) {
        if (member is MethodDeclaration) {
          final methodName = member.name.lexeme;
          if (methodName == 'fromJson' || methodName == 'toJson') {
            reporter.atNode(
              member,
              _code,
            );
          }
        } else if (member is ConstructorDeclaration) {
          // Verificar factory constructors con nombre fromJson
          final constructorName = member.name?.lexeme;
          if (constructorName == 'fromJson') {
            reporter.atNode(
              member,
              _code,
            );
          }
        }
      }
    });
  }
}

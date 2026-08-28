import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that enforces JSON serialization in data layer models.
/// Models should have fromJson/toJson methods or use @JsonSerializable/@freezed.
class ModelsMustHaveJsonSerialization extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [ModelsMustHaveJsonSerialization].
  const ModelsMustHaveJsonSerialization() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Genera los métodos con json_serializable o añade manualmente:\n'
        '  factory YourModel.fromJson(Map<String, dynamic> json) { ... }\n'
        '  Map<String, dynamic> toJson() { ... }\n'
        'O usa @freezed con fromJson:\n'
        '  @freezed\n'
        '  class YourModel with _\$YourModel {\n'
        '    const factory YourModel({required String id}) = _YourModel;\n'
        '    factory YourModel.fromJson(Map<String, dynamic> json) => _\$YourModelFromJson(json);\n'
        '  }',
    name: 'models_must_have_json_serialization',
    problemMessage:
        'Los models de data deben exponer fromJson/toJson o usar @JsonSerializable para interactuar con APIs.',
  );

  /// Executes the lint rule to detect models without serialization.
  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final uri = resolver.source.uri;
    final path = uri.path;

    // Solo aplicar en data/models/
    if (!path.contains('/data/models/')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Ignorar clases abstractas
      if (node.abstractKeyword != null) {
        return;
      }

      // Ignorar clases privadas (comienzan con _)
      final className = node.name.lexeme;
      if (className.startsWith('_')) {
        return;
      }

      // Verificar si tiene anotaciones @JsonSerializable o @freezed
      final hasJsonAnnotation = node.metadata.any((annotation) {
        final name = annotation.name.name;
        return name == 'JsonSerializable' ||
            name == 'jsonSerializable' ||
            name == 'freezed' ||
            name == 'Freezed';
      });

      if (hasJsonAnnotation) {
        return; // Tiene anotación, está OK
      }

      // Verificar si tiene métodos fromJson y toJson
      bool hasFromJson = false;
      bool hasToJson = false;

      for (final member in node.members) {
        if (member is MethodDeclaration) {
          final methodName = member.name.lexeme;
          if (methodName == 'toJson') {
            hasToJson = true;
          }
        } else if (member is ConstructorDeclaration) {
          final constructorName = member.name?.lexeme;
          if (constructorName == 'fromJson') {
            hasFromJson = true;
          }
        }
      }

      // Si no tiene ni anotaciones ni ambos métodos, reportar
      if (!hasFromJson || !hasToJson) {
        reporter.atNode(
          node,
          _code,
        );
      }
    });
  }
}

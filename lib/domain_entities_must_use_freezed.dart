import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Freezed convention: requires `@freezed`/`@Freezed` on concrete public classes
/// in `/domain/entities/` and `/domain/value_objects/`. Enabled by default;
/// projects that do not use Freezed disable it. Annotation spelling does not
/// prove deep immutability.
class DomainEntitiesMustUseFreezed extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [DomainEntitiesMustUseFreezed].
  DomainEntitiesMustUseFreezed() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'domain_entities_must_use_freezed',
    'Las entidades de domain deben declararse con @freezed para garantizar inmutabilidad y pattern matching.',
    correctionMessage:
        'Anota la clase con @freezed, cambia a const factory, y mueve los campos al factory constructor.\n'
        'Ejemplo:\n'
        '  @freezed\n'
        '  class User with _\$User {\n'
        '    const factory User({required String id, required String name}) = _User;\n'
        '  }',
  );

  /// Executes the lint rule to detect domain entities without @freezed.
  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    final uri = resolver.uri;
    final path = uri.path;

    // Solo aplicar en domain/entities/ y domain/value_objects/
    if (!path.contains('/domain/entities/') &&
        !path.contains('/domain/value_objects/')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Ignorar clases abstractas que definen interfaces
      if (node.abstractKeyword != null) {
        return;
      }

      // Ignorar clases privadas (comienzan con _)
      final className = node.namePart.typeName.lexeme;
      if (className.startsWith('_')) {
        return;
      }

      // Verificar si tiene la anotación @freezed
      final hasFreezed = node.metadata.any((annotation) {
        final name = annotation.name.name;
        return name == 'freezed' || name == 'Freezed';
      });

      if (!hasFreezed) {
        reporter.atNode(node, _code);
      }
    });
  }
}

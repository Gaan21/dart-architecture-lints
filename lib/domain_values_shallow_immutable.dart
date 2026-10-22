import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// Generator-independent, shallow immutability check for domain entities and
/// value objects in `/domain/entities/` and `/domain/value_objects/`.
///
/// Reports non-final instance fields (including abstract/external/covariant
/// ones), public `late final` fields without an initializer (they expose a
/// setter) and public instance setters in classes and mixins. Classes annotated
/// `@freezed`/`@Freezed` are accepted by annotation spelling and left to the
/// selected generator convention. Final fields may still reference mutable
/// objects or collections: this check does not prove deep immutability.
class DomainValuesShallowImmutable extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [DomainValuesShallowImmutable].
  const DomainValuesShallowImmutable() : super(code: _code);

  static const _code = LintCode(
    name: 'domain_values_shallow_immutable',
    problemMessage:
        'Domain entities and value objects must not declare mutable instance '
        'fields or public setters.',
    correctionMessage:
        'Make the field final (or `late final` with an initializer), remove the '
        'setter and return a new instance for changes. This shallow check does '
        'not prove that referenced objects or collections are immutable.',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.uri.path;
    if (!path.contains('/domain/entities/') &&
        !path.contains('/domain/value_objects/')) {
      return;
    }
    context.registry.addClassDeclaration((node) {
      if (_usesFreezed(node.metadata)) return;
      _checkMembers(node.members, reporter);
    });
    context.registry.addMixinDeclaration(
      (node) => _checkMembers(node.members, reporter),
    );
  }

  void _checkMembers(
    Iterable<ClassMember> members,
    DiagnosticReporter reporter,
  ) {
    for (final member in members) {
      if (member is FieldDeclaration && !member.isStatic) {
        final fields = member.fields;
        if (fields.isConst) continue;
        for (final variable in fields.variables) {
          final exposesSetter =
              fields.isLate &&
              variable.initializer == null &&
              !variable.name.lexeme.startsWith('_');
          if (!fields.isFinal || exposesSetter) {
            reporter.atNode(variable, _code);
          }
        }
      } else if (member is MethodDeclaration &&
          member.isSetter &&
          !member.isStatic &&
          !member.name.lexeme.startsWith('_')) {
        reporter.atNode(member, _code);
      }
    }
  }

  static bool _usesFreezed(NodeList<Annotation> metadata) =>
      metadata.any((annotation) {
        final name = annotation.name;
        final simple = name is PrefixedIdentifier
            ? name.identifier.name
            : name.name;
        return simple == 'freezed' || simple == 'Freezed';
      });
}

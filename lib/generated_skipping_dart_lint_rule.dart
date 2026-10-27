import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:yaml/yaml.dart';

import 'rule_node_registry.dart';

export 'rule_node_registry.dart' show RuleNodeRegistry;

/// The analyzed file: its absolute [path] and its `file:` [uri].
class LintFile {
  LintFile(this.path, this.uri);

  final String path;
  final Uri uri;
}

/// What a rule may use while registering callbacks for one file.
class LintRunContext {
  LintRunContext(this.registry, this._packageName);

  final RuleNodeRegistry registry;
  final String Function() _packageName;

  /// The `name` in the nearest `pubspec.yaml` above the file, or `''`.
  late final String packageName = _packageName();
}

/// Base class of every rule in this package.
///
/// Adapts the analyzer plugin API ([AnalysisRule]) to per-file callbacks: for
/// each compilation unit that does not look generated, [runOnNonGenerated]
/// registers node callbacks and reports through the unit's reporter.
abstract class GeneratedSkippingDartLintRule extends AnalysisRule {
  GeneratedSkippingDartLintRule({required this.code})
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The rule's diagnostic code. Diagnostics may use a [LintCode] with the
  /// same name and a more specific message.
  final LintCode code;

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(this, _UnitVisitor(this, context));
  }

  /// Registers this rule's callbacks for one non-generated file.
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  );
}

class _UnitVisitor extends SimpleAstVisitor<void> {
  _UnitVisitor(this.rule, this.context);

  final GeneratedSkippingDartLintRule rule;
  final RuleContext context;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final unit = context.currentUnit;
    if (unit == null) return;
    final file = LintFile(unit.file.path, unit.file.toUri());
    if (looksGenerated(file.uri)) return; // skips the whole file
    final registry = RuleNodeRegistry();
    rule.runOnNonGenerated(
      file,
      unit.diagnosticReporter,
      LintRunContext(registry, () => _packageName(unit.file)),
    );
    registry.run(node);
  }
}

/// The `name` of the nearest `pubspec.yaml` above [file], or `''`.
String _packageName(File file) {
  var folder = file.parent;
  while (true) {
    final pubspec = folder.getFile('pubspec.yaml');
    if (pubspec.exists) {
      try {
        final yaml = loadYaml(pubspec.readAsStringSync());
        final name = yaml is YamlMap ? yaml['name'] : null;
        return name is String ? name : '';
      } on Exception {
        return '';
      }
    }
    if (folder.isRoot) return '';
    folder = folder.parent;
  }
}

/// `MethodDeclaration.isAbstract` (deprecated in analyzer 13): a `;` body that
/// is not `external` and was not inserted by parser recovery.
bool isAbstractMethod(MethodDeclaration method) {
  final body = method.body;
  return method.externalKeyword == null &&
      body is EmptyFunctionBody &&
      !body.semicolon.isSynthetic;
}

/// Whether [uri] names a file produced by a code generator or build output.
bool looksGenerated(Uri uri) {
  final p = uri.path;
  // Typical generated-code suffixes and locations.
  const suffixes = [
    '.g.dart',
    '.freezed.dart',
    '.mocks.dart',
    '.gr.dart',
    '.gen.dart',
    '.pb.dart',
    '.pbenum.dart',
    '.pbjson.dart',
    '.pbgrpc.dart',
    '.swagger.dart',
    '.chopper.dart',
  ];
  if (p.contains('/generated/') ||
      p.contains('/.dart_tool/') ||
      p.contains('/build/')) {
    return true;
  }
  return suffixes.any(p.endsWith);
}

import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import 'generated_skipping_dart_lint_rule.dart';

typedef UnawaitedSelector = ({String path, String scope, String fingerprint});

/// Package-local policy, shared by the analyzer rule and checkout verifier.
class UnawaitedPermissions {
  UnawaitedPermissions._(this.root, this.selectors);

  final Folder root;
  final Set<UnawaitedSelector> selectors;

  static UnawaitedPermissions? forFile(File file) {
    var folder = file.parent;
    while (true) {
      if (folder.getFile('pubspec.yaml').exists) return load(folder);
      if (folder.isRoot) return null;
      folder = folder.parent;
    }
  }

  static UnawaitedPermissions? load(Folder root) {
    try {
      final pubspec = loadYaml(root.getFile('pubspec.yaml').readAsStringSync());
      if (pubspec is! YamlMap ||
          !pubspec.containsKey(
            'dart_architecture_lints_unawaited_permissions',
          )) {
        return null;
      }
      final path = pubspec['dart_architecture_lints_unawaited_permissions'];
      if (path is! String || !_validPath(path) || !path.endsWith('.json')) {
        throw const FormatException('Expected a package-relative JSON path.');
      }
      final manifest = jsonDecode(fileAt(root, path).readAsStringSync());
      if (manifest is! Map ||
          manifest.length != 2 ||
          manifest['version'] != 1 ||
          manifest['permissions'] is! List) {
        throw FormatException('$path: expected version 1 and permissions.');
      }
      final selectors = <UnawaitedSelector>{};
      for (final entry in manifest['permissions'] as List) {
        final selector = _parseEntry(entry);
        if (!selectors.add(selector)) {
          throw FormatException('$path: duplicate selector $selector.');
        }
      }
      return UnawaitedPermissions._(root, Set.unmodifiable(selectors));
    } on FileSystemException catch (error) {
      throw FormatException('Cannot read permission configuration: $error');
    } on YamlException catch (error) {
      throw FormatException('Invalid package configuration: $error');
    }
  }

  static UnawaitedSelector _parseEntry(Object? entry) {
    if (entry is! Map || entry.length != 6) {
      throw const FormatException('A permission must have exactly six fields.');
    }
    String text(String key) {
      final value = entry[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Permission requires nonblank "$key".');
      }
      return value;
    }

    final path = text('path');
    final scope = text('scope');
    final fingerprint = text('fingerprint');
    text('whyDetached');
    text('failureOwner');
    text('lateCompletion');
    if (!_validPath(path) ||
        !path.endsWith('.dart') ||
        looksGenerated(Uri(path: '/$path')) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint)) {
      throw FormatException('Invalid permission selector for $path ($scope).');
    }
    return (path: path, scope: scope, fingerprint: fingerprint);
  }

  static bool _validPath(String path) => path
      .split('/')
      .every(
        (part) =>
            part != '.' &&
            part != '..' &&
            RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(part),
      );

  static File fileAt(Folder root, String path) {
    final paths = root.provider.pathContext;
    return root.provider.getFile(
      paths.joinAll([root.path, ...path.split('/')]),
    );
  }

  String relativePath(File file) {
    final paths = root.provider.pathContext;
    return paths.split(paths.relative(file.path, from: root.path)).join('/');
  }
}

bool isDartUnawaited(MethodInvocation node) =>
    node.methodName.name == 'unawaited' &&
    node.methodName.element?.library?.uri == Uri.parse('dart:async');

/// Anonymous callbacks deliberately share the enclosing named scope. An
/// identical copy anywhere in that scope makes the selector ambiguous.
UnawaitedSelector selectUnawaited(String path, MethodInvocation node) {
  final scopes = <String>[];
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    final name = switch (parent) {
      ClassDeclaration() => 'class:${parent.namePart.typeName.lexeme}',
      MixinDeclaration() => 'mixin:${parent.name.lexeme}',
      EnumDeclaration() => 'enum:${parent.namePart.typeName.lexeme}',
      ExtensionDeclaration() => 'extension:${parent.name?.lexeme ?? ''}',
      MethodDeclaration() =>
        '${parent.isGetter
            ? 'get'
            : parent.isSetter
            ? 'set'
            : 'method'}:${parent.name.lexeme}',
      ConstructorDeclaration() => 'new:${parent.name?.lexeme ?? ''}',
      FunctionDeclaration() => 'function:${parent.name.lexeme}',
      VariableDeclaration() => 'variable:${parent.name.lexeme}',
      _ => null,
    };
    if (name != null) scopes.add(name);
  }

  final lexemes = <String>[];
  final end = node.endToken;
  for (Token? token = node.beginToken; token != null; token = token.next) {
    // dart format may remove/insert trailing commas when changing layout.
    if (token.lexeme != ',' ||
        !const {')', ']', '}', '>'}.contains(token.next?.lexeme)) {
      lexemes.add(token.lexeme);
    }
    if (identical(token, end)) break;
  }
  return (
    path: path,
    scope: scopes.isEmpty ? '<unit>' : scopes.reversed.join('/'),
    fingerprint: sha256.convert(utf8.encode(jsonEncode(lexemes))).toString(),
  );
}

Map<UnawaitedSelector, List<MethodInvocation>> unawaitedCalls(
  String path,
  CompilationUnit unit,
) {
  final visitor = _CallVisitor(path);
  unit.accept(visitor);
  return visitor.calls;
}

class _CallVisitor extends RecursiveAstVisitor<void> {
  _CallVisitor(this.path);

  final String path;
  final calls = <UnawaitedSelector, List<MethodInvocation>>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isDartUnawaited(node)) {
      (calls[selectUnawaited(path, node)] ??= []).add(node);
    }
    super.visitMethodInvocation(node);
  }
}

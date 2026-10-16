import 'dart:convert';
import 'dart:io';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:crypto/crypto.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/dart_architecture_lints.dart';
import 'package:package_config/package_config.dart';
import 'package:yaml/yaml.dart';

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _sorted(value[key])};
  }
  if (value is List) return value.map(_sorted).toList();
  return value;
}

/// Compact JSON, recursively sorted keys, preserved array order, one trailing LF.
String canonicalJson(Object? value) => '${jsonEncode(_sorted(value))}\n';

/// Hash original file bytes; use only package-relative POSIX paths as keys.
Map<String, String> sourceManifest(Directory root) {
  final base = root.absolute;
  final paths = <String>['pubspec.yaml', 'profiles/architecture.yaml'];
  for (final entity in Directory.fromUri(
    base.uri.resolve('lib/'),
  ).listSync(recursive: true, followLinks: false)) {
    if (entity is Link) {
      throw FormatException('Source manifest does not support symlinks in lib');
    }
    if (entity is File && entity.path.endsWith('.dart')) {
      final prefix = base.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .length;
      paths.add(entity.absolute.uri.pathSegments.skip(prefix).join('/'));
    }
  }
  paths.sort();
  return {
    for (final path in paths)
      path: sha256
          .convert(
            File.fromUri(
              base.uri.resolveUri(Uri(path: path)),
            ).readAsBytesSync(),
          )
          .toString(),
  };
}

String sourceDigest(Directory root) =>
    sha256.convert(utf8.encode(canonicalJson(sourceManifest(root)))).toString();

/// Self-attests the current checkout, not an application's resolved installation.
String exportContract(Directory root, {String? expectedArchitecture}) {
  final pubspec =
      loadYaml(
            File.fromUri(
              root.absolute.uri.resolve('pubspec.yaml'),
            ).readAsStringSync(),
          )
          as Map;
  final profileFile = File.fromUri(
    root.absolute.uri.resolve('profiles/architecture.yaml'),
  );
  final source = profileFile.readAsStringSync();
  if (expectedArchitecture != null && source != expectedArchitecture) {
    throw FormatException(
      'Architecture profile drift; regenerate before exporting a contract',
    );
  }
  final configs = CustomLintConfigs.parse(
    PhysicalResourceProvider.INSTANCE.getFile(profileFile.absolute.path),
    PackageConfig([]),
  );
  final registered = createPlugin().getLintRules(configs);
  final rules = <String, Object?>{};
  for (final rule in registered) {
    final id = rule.code.name;
    if (rules.containsKey(id)) {
      throw FormatException('Duplicate contract rule: $id');
    }
    final options = configs.rules[id];
    if (options == null) {
      throw FormatException('Missing contract selection: $id');
    }
    rules[id] = {
      'enabled': rule.isEnabled(configs),
      'options': options.json,
      'severity': rule.code.errorSeverity.name.toUpperCase(),
    };
  }
  if (configs.rules.length != rules.length) {
    throw FormatException('Unknown contract selections');
  }
  return canonicalJson({
    'schema': 1,
    'package': pubspec['name'],
    'version': pubspec['version'].toString(),
    'source_digest': sourceDigest(root),
    'profile': 'architecture',
    'rules': rules,
  });
}

/// Exact canonical byte comparison also catches schema/options/selection drift.
void verifyContract(File file, String expected) {
  final bytes = file.readAsBytesSync();
  final wanted = utf8.encode(expected);
  if (bytes.length != wanted.length ||
      Iterable<int>.generate(
        bytes.length,
      ).any((index) => bytes[index] != wanted[index])) {
    throw FormatException('Contract differs from this checkout: ${file.path}');
  }
}

void writeContract(File file, String contract, Directory root) {
  final absolute = File(
    '${file.parent.resolveSymbolicLinksSync()}/${file.uri.pathSegments.last}',
  ).absolute.uri;
  if (FileSystemEntity.isLinkSync(file.path)) {
    throw FormatException('Contract output must not be a symlink');
  }
  if (sourceManifest(root).keys.any(
        (path) =>
            File.fromUri(
              root.absolute.uri.resolveUri(Uri(path: path)),
            ).resolveSymbolicLinksSync() ==
            File.fromUri(absolute).path,
      ) ||
      absolute.path.startsWith(
        Directory('${root.resolveSymbolicLinksSync()}/lib').uri.path,
      )) {
    throw FormatException('Cannot overwrite contract source inputs');
  }
  file.writeAsStringSync(contract, encoding: utf8);
}

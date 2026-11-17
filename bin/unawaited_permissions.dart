import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:dart_architecture_lints/unawaited_permissions.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2 ||
      (args.first != 'verify' && args.first != 'list') ||
      (args.first == 'verify' && args.length != 2)) {
    stderr.writeln(
      'Usage: unawaited_permissions verify PACKAGE_ROOT\n'
      '       unawaited_permissions list PACKAGE_ROOT PACKAGE_RELATIVE_DART_FILES...',
    );
    exitCode = 64;
    return;
  }

  final provider = PhysicalResourceProvider.INSTANCE;
  final root = provider.getFolder(
    provider.pathContext.normalize(Directory(args[1]).absolute.path),
  );
  try {
    final verify = args.first == 'verify';
    final permissions = verify ? UnawaitedPermissions.load(root) : null;
    if (verify && permissions == null) {
      throw const FormatException('Manifest mode is not enabled.');
    }
    final paths = verify
        ? permissions!.selectors.map((selector) => selector.path).toSet()
        : args.skip(2).toSet();
    final contexts = AnalysisContextCollection(includedPaths: [root.path]);
    try {
      for (final path in paths) {
        final file = UnawaitedPermissions.fileAt(root, path);
        if (!file.exists) {
          stderr.writeln('$path: permission source file is missing.');
          exitCode = 1;
          continue;
        }
        final result = await contexts
            .contextFor(file.path)
            .currentSession
            .getResolvedUnit(file.path);
        if (result is! ResolvedUnitResult) {
          stderr.writeln('$path: cannot resolve source file.');
          exitCode = 1;
          continue;
        }
        final calls = unawaitedCalls(path, result.unit);
        if (verify) {
          for (final selector in permissions!.selectors.where(
            (s) => s.path == path,
          )) {
            final count = calls[selector]?.length ?? 0;
            if (count != 1) {
              stderr.writeln('$selector: expected one match, found $count.');
              exitCode = 1;
            }
          }
        } else {
          for (final entry in calls.entries) {
            for (final call in entry.value) {
              stdout.writeln(
                jsonEncode({
                  'path': path,
                  'scope': entry.key.scope,
                  'fingerprint': entry.key.fingerprint,
                  'line': result.lineInfo.getLocation(call.offset).lineNumber,
                  'call': result.content.substring(call.offset, call.end),
                }),
              );
            }
          }
        }
      }
      if (verify && exitCode == 0) {
        stdout.writeln(
          'Verified ${permissions!.selectors.length} permission(s).',
        );
      }
    } finally {
      await contexts.dispose();
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on ArgumentError catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import '../tool/contract_export.dart' as contract;
import '../tool/generate_rule_tables.dart' as generator;

void main() {
  test(
    'canonical encoding sorts recursively, preserves arrays, and terminates with one LF',
    () {
      expect(
        contract.canonicalJson({
          'z': [2, 1],
          'a': {'z': true, 'a': {}},
        }),
        '{"a":{"a":{},"z":true},"z":[2,1]}\n',
      );
    },
  );
  test(
    'schema, identity, selections, options and default severities are exact',
    () {
      final encoded = contract.exportContract(Directory.current);
      expect(contract.exportContract(Directory.current), encoded);
      final parsed = jsonDecode(encoded) as Map<String, dynamic>;
      expect(parsed.keys.toSet(), {
        'schema',
        'package',
        'version',
        'source_digest',
        'profile',
        'rules',
      });
      expect(parsed['schema'], 1);
      expect(parsed['package'], 'dart_architecture_lints');
      expect(parsed['version'], '0.0.6');
      expect(parsed['profile'], 'architecture');
      expect(parsed['source_digest'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(encoded, contract.canonicalJson(parsed));
      final rules = parsed['rules'] as Map<String, dynamic>;
      final actual = generator.registeredRules();
      expect(rules.keys.toSet(), actual.keys.toSet());
      final selected = generator.profileSelections(actual.keys, 'architecture');
      for (final entry in actual.entries) {
        expect((rules[entry.key] as Map).keys.toSet(), {
          'enabled',
          'options',
          'severity',
        });
        expect(rules[entry.key]['enabled'], selected[entry.key]);
        expect(
          rules[entry.key]['severity'],
          entry.value.code.errorSeverity.name.toUpperCase(),
        );
      }
      expect(rules['require_explicit_types']['options'], {
        'policy': 'selective',
      });
      expect(rules['logger_context_matches_scope']['options'], {
        'include_globs': ['**/lib/**'],
        'logger_names': ['Logger', 'logger'],
      });
      expect(rules['method_order']['options'], isEmpty);
    },
  );
  test(
    'manifest hashes original bytes and every required relative path; mutations change identity',
    () async {
      final root = await Directory.systemTemp.createTemp('contract_source_');
      final replica = await Directory.systemTemp.createTemp(
        'contract_replica_',
      );
      try {
        const files = {
          'pubspec.yaml': 'name: dart_architecture_lints\nversion: 0.0.6\n',
          'profiles/architecture.yaml': 'custom_lint: {}\n',
          'lib/z.dart': '// original\r\n',
          'lib/nested/a file.dart': '// nested\n',
          'lib/percent%file.dart': '// percent path\n',
        };
        for (final directory in [root, replica]) {
          for (final entry in files.entries) {
            final file = File('${directory.path}/${entry.key}');
            await file.parent.create(recursive: true);
            await file.writeAsString(entry.value);
          }
        }
        final manifest = contract.sourceManifest(root);
        expect(manifest.keys, [
          'lib/nested/a file.dart',
          'lib/percent%file.dart',
          'lib/z.dart',
          'profiles/architecture.yaml',
          'pubspec.yaml',
        ]);
        for (final entry in files.entries) {
          expect(
            manifest[entry.key],
            sha256.convert(utf8.encode(entry.value)).toString(),
          );
        }
        final original = contract.sourceDigest(root);
        expect(
          original,
          sha256
              .convert(utf8.encode(contract.canonicalJson(manifest)))
              .toString(),
        );
        expect(contract.sourceDigest(replica), original);
        for (final path in files.keys) {
          await File(
            '${root.path}/$path',
          ).writeAsString('${files[path]}// changed\n');
          expect(contract.sourceDigest(root), isNot(original), reason: path);
          await File('${root.path}/$path').writeAsString(files[path]!);
        }
        await File(
          '${root.path}/lib/added.dart',
        ).writeAsString('// additional\n');
        expect(contract.sourceDigest(root), isNot(original));
        await File(
          '${replica.path}/unrelated.md',
        ).writeAsString('not a source input\n');
        expect(contract.sourceDigest(replica), original);
      } finally {
        await root.delete(recursive: true);
        await replica.delete(recursive: true);
      }
    },
  );
  test(
    'verification rejects mutation and noncanonical bytes; export cannot overwrite inputs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'contract_artifact_',
      );
      try {
        final file = File('${directory.path}/contract.json');
        final encoded = contract.exportContract(Directory.current);
        contract.writeContract(file, encoded, Directory.current);
        contract.verifyContract(file, encoded);
        expect(file.readAsStringSync(), encoded);
        for (final changed in [
          encoded.trimRight(),
          encoded.replaceFirst('"schema":1', '"schema":2'),
          encoded.replaceFirst('"enabled":true', '"enabled":false'),
        ]) {
          await file.writeAsString(changed);
          expect(
            () => contract.verifyContract(file, encoded),
            throwsFormatException,
          );
        }
        expect(
          () => contract.writeContract(
            File('pubspec.yaml'),
            encoded,
            Directory.current,
          ),
          throwsFormatException,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'CLI export and verify work together with guidance checking',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'paired_contract_',
      );
      try {
        final guidance = File('${directory.path}/profiles/architecture.md');
        await guidance.parent.create();
        final selections = generator.profileSelections(
          generator.registeredRules().keys,
          'architecture',
        );
        await guidance.writeAsString(
          '| Rule | Selection |\n|---|---|\n${selections.entries.map((entry) => '| `${entry.key}` | ${entry.value ? 'enabled' : 'disabled'} |').join('\n')}\n',
        );
        final path = '${directory.path}/contract.json';
        Future<ProcessResult> run(List<String> args) => Process.run(
          Platform.resolvedExecutable,
          ['run', 'tool/generate_rule_tables.dart', ...args],
        );
        final exported = await run([
          '--check',
          '--guidance-root',
          directory.path,
          '--export-contract',
          path,
        ]);
        expect(
          exported.exitCode,
          0,
          reason: '${exported.stderr}\n${exported.stdout}',
        );
        final bytes = File(path).readAsBytesSync();
        expect(bytes, utf8.encode(contract.exportContract(Directory.current)));
        final verified = await run(['--verify-contract=$path']);
        expect(
          verified.exitCode,
          0,
          reason: '${verified.stderr}\n${verified.stdout}',
        );
        expect(File(path).readAsBytesSync(), bytes);
        await File(path).writeAsString('{}\n');
        final rejected = await run(['--verify-contract', path]);
        expect(rejected.exitCode, isNonZero);
        expect(rejected.stderr, contains('Contract differs'));
      } finally {
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

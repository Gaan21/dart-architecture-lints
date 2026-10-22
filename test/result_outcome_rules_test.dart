// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/datasources_return_result.dart';
import 'package:dart_architecture_lints/no_result_throw.dart';
import 'package:dart_architecture_lints/repository_methods_return_result.dart';
import 'package:test/test.dart';
import 'rule_test_support.dart';

const _result = '''
import 'dart:async';
class Result<T> { const Result(this.value); final T? value; }
typedef AsyncResult<T> = Future<Result<T>>;
''';

/// Names of the reported members (method or getter) or throwing members.
Set<String> _reported(List<AnalysisError> errors, String source) {
  final names = <String>{};
  for (final error in errors) {
    final text = source.substring(error.offset, error.offset + error.length);
    final match = RegExp(r'get\s+(\w+)|(\w+)\s*\(').firstMatch(text)!;
    names.add(match.group(1) ?? match.group(2)!);
  }
  return names;
}

void main() {
  group('repository_methods_return_result', () {
    const source =
        '''
$_result
abstract interface class RecordContract { Future<int> fetch(); }
class RecordRepositoryImpl implements RecordContract {
  Future<int> count() async => 1;
  int compute(int value) => value * 2;
  Stream<int> get changes => Stream.value(1);
  Future<int> get total async => 1;
  @override
  fetch() async => 1;
  Future<Result<int>> load() async => const Result(1);
  Result<int> validate(String raw) => Result(raw.length);
  Stream<Result<int>> watch() => Stream.value(const Result(1));
  FutureOr<Result<int>> maybe() => const Result(1);
  AsyncResult<int> aliased() async => const Result(1);
  int get cachedCount => 1;
  int _calculate() => 2;
  Future<void> init() async => _calculate();
  Stream<void> pulses() => const Stream.empty();
  set label(String value) {}
  @override
  String toString() => 'RecordRepositoryImpl';
}
''';

    test('public operations need Result; getters/helpers may not', () async {
      final errors = await runRule(
        const RepositoryMethodsReturnResult(),
        source,
        path: 'lib/data/repositories/record_repository.dart',
      );
      expect(_reported(errors, source), {
        'count',
        'compute',
        'changes',
        'total',
        'fetch',
      });
      expect(errors, hasLength(5));
    });

    test('files outside data/repositories are out of scope', () async {
      expect(
        await runRule(
          const RepositoryMethodsReturnResult(),
          source,
          path: 'lib/domain/repositories/record_repository.dart',
        ),
        isEmpty,
      );
    });
  });

  test(
    'datasources_return_result checks abstract and async-getter operations',
    () async {
      const source =
          '''
$_result
abstract interface class RecordDataSource {
  Future<int> fetch();
  int parse(String raw);
  Stream<int> get updates;
  Future<Result<int>> load();
  FutureOr<Result<int>> cached();
  AsyncResult<int> aliased();
  Stream<Result<int>> watch();
  int get timeoutSeconds;
  Future<void> clear();
}
''';
      final errors = await runRule(
        const DataSourcesReturnResult(),
        source,
        path: 'lib/data/dataSources/remote/record_data_source.dart',
      );
      expect(_reported(errors, source), {'fetch', 'parse', 'updates'});
      expect(errors, hasLength(3));
    },
  );

  test('no_result_throw exempts only throws caught in the same body', () async {
    const source =
        '''
$_result
class FormatFailure implements Exception {}
class RecordRepository {
  Result<int> parse(String raw) {
    try {
      if (raw.isEmpty) throw FormatFailure();
      return Result(raw.length);
    } on FormatFailure {
      return const Result(null);
    }
  }
  Result<int> guarded() {
    try { throw StateError('state'); } catch (error) { return const Result(null); }
  }
  Result<int> wrongType() {
    try { throw StateError('state'); } on FormatFailure { return const Result(null); }
  }
  Result<int> escapes() {
    try { return const Result(1); } catch (error) { rethrow; }
  }
  Result<int> nested() {
    try {
      try { return const Result(1); } on FormatFailure { rethrow; }
    } on Exception {
      return const Result(null);
    }
  }
  Result<int> fromCatch() {
    try { return const Result(1); } catch (error) { throw FormatFailure(); }
  }
  Result<List<int>> closure() {
    try {
      return Result([1].map((v) => v > 0 ? v : throw FormatFailure()).toList());
    } catch (error) {
      return const Result(null);
    }
  }
  int _helper() => throw FormatFailure();
  int helperUse() => _helper();
}
''';
    final errors = await runRule(const NoResultThrowLint(), source);
    expect(errors, hasLength(5));
    final lines = {
      for (final error in errors)
        source.substring(0, error.offset).split('\n').length,
    };
    final expected = {
      for (final marker in [
        'try { throw StateError(\'state\'); } on FormatFailure',
        'catch (error) { rethrow; }',
        'catch (error) { throw FormatFailure(); }',
        'v > 0 ? v : throw',
        '_helper() => throw',
      ])
        source.substring(0, source.indexOf(marker)).split('\n').length,
    };
    expect(lines, expected);
  });
}

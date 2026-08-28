import 'package:custom_lint_builder/custom_lint_builder.dart';

String normalizeLintPath(String path) => path.replaceAll('\\', '/');

bool matchesAnyGlob(String filePath, List<String> globs) {
  final normalizedPath = normalizeLintPath(filePath);
  for (final glob in globs) {
    if (_globToRegExp(glob).hasMatch(normalizedPath)) return true;
  }
  return false;
}

RegExp _globToRegExp(String glob) {
  final normalizedGlob = normalizeLintPath(glob);
  final buffer = StringBuffer('^');

  var index = 0;
  while (index < normalizedGlob.length) {
    final char = normalizedGlob[index];
    if (char == '*') {
      final hasDoubleStar =
          index + 1 < normalizedGlob.length && normalizedGlob[index + 1] == '*';
      if (hasDoubleStar) {
        buffer.write('.*');
        index += 2;
        continue;
      }
      buffer.write('[^/]*');
      index += 1;
      continue;
    }

    if (char == '?') {
      buffer.write('[^/]');
      index += 1;
      continue;
    }

    if (_regexSpecialChars.contains(char)) {
      buffer.write('\\$char');
    } else {
      buffer.write(char);
    }
    index += 1;
  }

  buffer.write(r'$');
  return RegExp(buffer.toString());
}

const _regexSpecialChars = r'.^$+()[]{}|';

List<String> readStringListOption(
  Map<String, Object?> json,
  String key, {
  List<String> fallback = const [],
}) {
  final raw = json[key];
  if (raw is List) {
    return raw.whereType<String>().map((item) => item.trim()).where((item) {
      return item.isNotEmpty;
    }).toList();
  }

  if (raw is String && raw.trim().isNotEmpty) {
    return [raw.trim()];
  }

  return fallback;
}

bool readBoolOption(
  Map<String, Object?> json,
  String key, {
  required bool fallback,
}) {
  final raw = json[key];
  if (raw is bool) return raw;
  return fallback;
}

Map<String, Object?> readRuleOptions(
  CustomLintConfigs configs,
  String ruleName,
) {
  return configs.rules[ruleName]?.json ?? const <String, Object?>{};
}

bool wildcardMatch(String value, String pattern) {
  final escaped = RegExp.escape(pattern).replaceAll(r'\*', '.*');
  return RegExp('^$escaped\$').hasMatch(value);
}

bool matchesAnyWildcard(String value, Iterable<String> patterns) {
  for (final pattern in patterns) {
    if (wildcardMatch(value, pattern)) return true;
  }
  return false;
}

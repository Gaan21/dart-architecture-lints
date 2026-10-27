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

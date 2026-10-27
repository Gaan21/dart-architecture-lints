import 'timezone_safety_utils.dart';

/// Explicit file-level exceptions for civil calendars and clock adapters.
class TimeScope {
  const TimeScope({
    this.includeGlobs = const ['**'],
    this.excludeGlobs = const [],
    this.civilGlobs = const [],
    this.clockGlobs = const [],
  });

  final List<String> includeGlobs, excludeGlobs, civilGlobs, clockGlobs;
  bool includes(String path) =>
      matchesAnyGlob(path, includeGlobs) && !matchesAnyGlob(path, excludeGlobs);
  bool civil(String path) => matchesAnyGlob(path, civilGlobs);
  bool clock(String path) => matchesAnyGlob(path, clockGlobs);
}

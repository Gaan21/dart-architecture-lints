import 'package:analyzer/dart/element/type.dart';

/// Includes inferred types, aliases and resource subclasses.
bool isResourceType(DartType? type, Set<String> names, {String? libraryUri}) {
  if (type is! InterfaceType) return false;
  bool matches(InterfaceType type) =>
      names.contains(type.element.name) &&
      (libraryUri == null || type.element.library.uri.toString() == libraryUri);
  return matches(type) || type.allSupertypes.any(matches);
}

const lifecycleResourceNames = {
  'TextEditingController',
  'ScrollController',
  'AnimationController',
  'TabController',
  'PageController',
  'FocusNode',
  'Timer',
  'StreamController',
  'StreamSubscription',
  'VideoPlayerController',
  'CameraController',
};

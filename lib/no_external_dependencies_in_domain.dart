import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/error/error.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prevents external dependencies in domain layer.
/// Following Clean Architecture principles, domain should only depend on Dart core.
class NoExternalDependenciesInDomainLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoExternalDependenciesInDomainLint].
  NoExternalDependenciesInDomainLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    'no_external_dependencies_in_domain',
    'Domain layer contains external dependency, violating Clean Architecture. The domain should only depend on abstract interfaces and Dart core.',
    correctionMessage: 'Remove this external dependency. Create an interface in the domain layer and implement it in the infrastructure layer using dependency inversion.',
  );

  @override
  void runOnNonGenerated(
    LintFile resolver,
    DiagnosticReporter reporter,
    LintRunContext context,
  ) {
    context.registry.addImportDirective((ImportDirective node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      // Check if we're in a domain file
      final filePath = resolver.path;
      if (!_isDomainFile(filePath)) return;

      // Check if this is a prohibited external dependency
      if (_isProhibitedDependency(uri)) {
        final category = _getDependencyCategory(uri);
        final customCode = LintCode(
          'no_external_dependencies_in_domain',
          'Domain layer should not depend on $category packages. '
              'This violates Clean Architecture principles.',
          correctionMessage:
              'Remove this $category dependency from domain. '
              'Use dependency inversion to access external services.',
        );
        reporter.atNode(node.uri, customCode);
      }
    });
  }

  /// Checks if the file is within the domain layer.
  bool _isDomainFile(String filePath) {
    // Check if path contains 'domain' directory
    final segments = filePath.split('/');

    // Exclude test files
    if (segments.any((segment) => segment.toLowerCase().contains('test'))) {
      return false;
    }

    return segments.contains('domain');
  }

  /// Checks if a dependency is prohibited in domain layer.
  bool _isProhibitedDependency(String uri) {
    // Allow Dart core libraries
    if (uri.startsWith('dart:')) return false;

    // Allow relative imports (internal project files)
    if (!uri.startsWith('package:')) return false;

    // Allow specific annotation packages commonly used in domain
    final allowedPackages = {
      'meta',
      'freezed_annotation',
      'json_annotation',
      'equatable',
      'dartz', // For functional programming
    };

    for (final allowed in allowedPackages) {
      if (uri.startsWith('package:$allowed/')) return false;
    }

    // Allow imports from same project (internal domain dependencies)
    // This is more complex to detect reliably, so we'll be conservative
    // and only flag clearly external packages

    return _isKnownExternalPackage(uri);
  }

  /// Checks if a package is a known external dependency.
  bool _isKnownExternalPackage(String uri) {
    final prohibitedPrefixes = [
      // Flutter framework
      'package:flutter/',

      // State management
      'package:provider/',
      'package:bloc/',
      'package:flutter_bloc/',
      'package:riverpod/',
      'package:flutter_riverpod/',
      'package:get/',
      'package:mobx/',
      'package:flutter_mobx/',

      // HTTP/Network
      'package:dio/',
      'package:http/',
      'package:chopper/',
      'package:retrofit/',

      // Storage/Database
      'package:hive/',
      'package:hive_flutter/',
      'package:sqflite/',
      'package:shared_preferences/',
      'package:sembast/',
      'package:drift/',
      'package:moor/',

      // Platform services
      'package:path_provider/',
      'package:device_info/',
      'package:device_info_plus/',
      'package:permission_handler/',
      'package:package_info/',
      'package:package_info_plus/',

      // Firebase
      'package:firebase_core/',
      'package:firebase_auth/',
      'package:cloud_firestore/',
      'package:firebase_analytics/',
      'package:firebase_messaging/',
      'package:firebase_storage/',

      // UI/Navigation
      'package:go_router/',
      'package:auto_route/',
      'package:beamer/',

      // Testing (though domain tests might be in test folders)
      'package:flutter_test/',
      'package:integration_test/',

      // Logging
      'package:logger/',

      // Image/Media
      'package:image_picker/',
      'package:camera/',

      // Location
      'package:location/',
      'package:geolocator/',
    ];

    return prohibitedPrefixes.any((prefix) => uri.startsWith(prefix));
  }

  /// Gets the category of dependency for better error messages.
  String _getDependencyCategory(String uri) {
    if (uri.startsWith('package:flutter/')) return 'Flutter framework';

    final stateManagementPackages = [
      'provider',
      'bloc',
      'flutter_bloc',
      'riverpod',
      'flutter_riverpod',
      'get',
      'mobx',
      'flutter_mobx',
    ];
    if (stateManagementPackages.any((pkg) => uri.startsWith('package:$pkg/'))) {
      return 'state management';
    }

    final networkPackages = ['dio', 'http', 'chopper', 'retrofit'];
    if (networkPackages.any((pkg) => uri.startsWith('package:$pkg/'))) {
      return 'networking';
    }

    final storagePackages = [
      'hive',
      'hive_flutter',
      'sqflite',
      'shared_preferences',
      'sembast',
      'drift',
      'moor',
    ];
    if (storagePackages.any((pkg) => uri.startsWith('package:$pkg/'))) {
      return 'storage/database';
    }

    final platformPackages = [
      'path_provider',
      'device_info',
      'device_info_plus',
      'permission_handler',
      'package_info',
      'package_info_plus',
    ];
    if (platformPackages.any((pkg) => uri.startsWith('package:$pkg/'))) {
      return 'platform service';
    }

    final firebasePackages = [
      'firebase_core',
      'firebase_auth',
      'cloud_firestore',
      'firebase_analytics',
      'firebase_messaging',
      'firebase_storage',
    ];
    if (firebasePackages.any((pkg) => uri.startsWith('package:$pkg/'))) {
      return 'Firebase';
    }

    final uiPackages = ['go_router', 'auto_route', 'beamer'];
    if (uiPackages.any((pkg) => uri.startsWith('package:$pkg/'))) {
      return 'navigation/UI';
    }

    final testingPackages = ['flutter_test', 'integration_test'];
    if (testingPackages.any((pkg) => uri.startsWith('package:$pkg/'))) {
      return 'testing framework';
    }

    return 'external';
  }
}

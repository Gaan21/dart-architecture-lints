import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';

/// A lint rule that prevents direct internet calls outside of NetworkService.
/// Enforces centralized network management for better connectivity handling.
class NoDirectInternetCallsLint extends GeneratedSkippingDartLintRule {
  /// Creates an instance of [NoDirectInternetCallsLint].
  const NoDirectInternetCallsLint() : super(code: _code);

  /// The lint code associated with this rule.
  static const _code = LintCode(
    correctionMessage:
        'Route this network call through a NetworkService or similar abstraction to centralize connectivity management, error handling, and offline support.',
    name: 'no_direct_internet_calls',
    problemMessage:
        'Direct network calls bypass centralized connectivity management. This makes offline handling and network error management inconsistent.',
  );

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Skip if this is a network service file itself
    if (_isNetworkServiceFile(filePath)) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      _checkDirectInternetCall(node, reporter);
    });

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      _checkNetworkInstanceCreation(node, reporter);
    });
  }

  /// Checks if the file is a network service that's allowed to make direct calls.
  bool _isNetworkServiceFile(String filePath) {
    final fileName = filePath.split('/').last.toLowerCase();
    final pathSegments = filePath.toLowerCase().split('/');

    // Allow files that are clearly network services
    final networkIndicators = [
      'network_service',
      'networkservice',
      'connectivity_service',
      'connectivityservice',
      'http_service',
      'httpservice',
      'api_service',
      'apiservice',
      'dio_service',
      'dioservice',
      'di_container', // <-- AÑADIR
      'dependency_injection',
    ];

    // Check filename
    if (networkIndicators.any((indicator) => fileName.contains(indicator))) {
      return true;
    }

    // Check if in dedicated network/services folder
    if (pathSegments.contains('network') || pathSegments.contains('services')) {
      return fileName.contains('service') || fileName.contains('client');
    }

    return false;
  }

  /// Checks for direct internet method calls.
  void _checkDirectInternetCall(
      MethodInvocation node, DiagnosticReporter reporter) {
    final invocationTarget = node.realTarget ?? node.target;

    // Allow delegated calls through variables like networkService / NetworkService.
    if (_isAllowedNetworkServiceTarget(invocationTarget)) return;

    // Check for HTTP method calls (get, post, put, delete, patch)
    if (_isHttpMethodCall(node)) {
      reporter.atNode(node, _code);
      return;
    }

    // Check for connectivity checks
    if (_isConnectivityCall(node)) {
      const customCode = LintCode(
        name: 'no_direct_internet_calls',
        problemMessage:
            'Direct connectivity checks should go through NetworkService for consistent offline handling.',
        correctionMessage:
            'Use NetworkService.hasConnection() instead of direct connectivity checks',
      );
      reporter.atNode(node, customCode);
      return;
    }
  }

  /// Checks for network-related instance creation.
  void _checkNetworkInstanceCreation(
      InstanceCreationExpression node, DiagnosticReporter reporter) {
    // Check for Dio() instances
    if (_isDioCreation(node)) {
      reporter.atNode(node, _code);
      return;
    }

    // Check for http.Client() instances
    if (_isHttpClientCreation(node)) {
      reporter.atNode(node, _code);
      return;
    }

    // Check for Connectivity() instances
    if (_isConnectivityCreation(node)) {
      const customCode = LintCode(
        name: 'no_direct_internet_calls',
        problemMessage:
            'Direct Connectivity instances should be managed by NetworkService for centralized handling.',
        correctionMessage:
            'Use NetworkService.hasConnection() instead of creating Connectivity instances',
      );
      reporter.atNode(node, customCode);
      return;
    }
  }

  /// Allows calls when the invocation target clearly references NetworkService.
  bool _isAllowedNetworkServiceTarget(Expression? target) {
    if (target == null) return false;

    final normalizedTarget = target.toSource().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );

    return normalizedTarget.contains('networkservice');
  }

  /// Checks if method invocation is an HTTP method call.
  bool _isHttpMethodCall(MethodInvocation node) {
    final methodName = node.methodName.name;
    final httpMethods = {
      'get',
      'post',
      'put',
      'delete',
      'patch',
      'head',
      'options'
    };

    if (!httpMethods.contains(methodName)) return false;

    // Check if called on Dio, http, or similar
    final target = node.target;

    // Static calls like http.get()
    if (target is Identifier) {
      final targetName = target.name;
      return targetName == 'http' || targetName == 'Dio';
    }

    // Instance calls like dio.get(), client.post()
    if (target is MethodInvocation || target is InstanceCreationExpression) {
      return true; // Likely an HTTP client instance
    }

    return false;
  }

  /// Checks if method invocation is a connectivity call.
  bool _isConnectivityCall(MethodInvocation node) {
    final methodName = node.methodName.name;
    final connectivityMethods = {
      'checkConnectivity',
      'hasConnection',
      'isConnected',
    };

    if (!connectivityMethods.contains(methodName)) return false;

    // Check if called on Connectivity or similar
    final target = node.target;
    if (target is Identifier && target.name == 'Connectivity') return true;

    // Instance calls on connectivity objects
    return true;
  }

  /// Checks if instance creation is Dio().
  bool _isDioCreation(InstanceCreationExpression node) {
    final type = node.constructorName.type;
    return type.name.lexeme == 'Dio';
  }

  /// Checks if instance creation is http.Client().
  bool _isHttpClientCreation(InstanceCreationExpression node) {
    final constructorName = node.constructorName;

    // Check for http.Client()
    if (constructorName.type.name.lexeme == 'Client') {
      // Could be http.Client or other Client, but in context of HTTP it's likely http.Client
      return true;
    }

    // Check for specific HTTP client types
    final httpClientTypes = {
      'HttpClient',
      'IOClient',
      'BrowserClient',
    };

    return httpClientTypes.contains(constructorName.type.name.lexeme);
  }

  /// Checks if instance creation is Connectivity().
  bool _isConnectivityCreation(InstanceCreationExpression node) {
    final type = node.constructorName.type;
    return type.name.lexeme == 'Connectivity';
  }
}

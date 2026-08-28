import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:dart_architecture_lints/timezone_safety_utils.dart';

class NoCivilUtcMixWithoutHelperLint extends GeneratedSkippingDartLintRule {
  const NoCivilUtcMixWithoutHelperLint({
    this.config = const NoCivilUtcMixWithoutHelperConfig(),
  }) : super(code: _code);

  final NoCivilUtcMixWithoutHelperConfig config;

  static const _code = LintCode(
    name: 'no_civil_utc_mix_without_helper',
    problemMessage:
        'Detected civil-date + UTC-instant mix without approved helper.',
    correctionMessage:
        'Normalize with an approved helper (for example, TimeContract.normalizeCivilDate) before comparing, formatting, or concatenating.',
  );

  static NoCivilUtcMixWithoutHelperLint fromConfigs(CustomLintConfigs configs) {
    final options = readRuleOptions(configs, _code.name);
    return NoCivilUtcMixWithoutHelperLint(
      config: NoCivilUtcMixWithoutHelperConfig.fromJson(options),
    );
  }

  @override
  void runOnNonGenerated(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = normalizeLintPath(resolver.path);
    if (!config.matchesPath(path)) return;

    final reportedOffsets = <int>{};

    void reportIfNeeded(AstNode node) {
      final offset = node.offset;
      if (offset < 0 || reportedOffsets.contains(offset)) return;
      if (config.isInsideWhitelistedHelper(node)) return;

      final shouldReport = switch (node) {
        BinaryExpression binary => _shouldReportBinary(binary),
        StringInterpolation interpolation =>
          _shouldReportInterpolation(interpolation),
        MethodInvocation invocation => _shouldReportInvocation(invocation),
        _ => false,
      };

      if (!shouldReport) return;

      reportedOffsets.add(offset);
      reporter.atNode(node, _code);
    }

    context.registry.addBinaryExpression(reportIfNeeded);
    context.registry.addStringInterpolation(reportIfNeeded);
    context.registry.addMethodInvocation(reportIfNeeded);
  }

  bool _shouldReportBinary(BinaryExpression node) {
    if (!config.strictMode && !_isRiskyBinaryOperator(node.operator.lexeme)) {
      return false;
    }

    final left = _TimeSignalCollector.collect(node.leftOperand);
    final right = _TimeSignalCollector.collect(node.rightOperand);
    return (left.hasCivil && right.hasInstant) ||
        (left.hasInstant && right.hasCivil);
  }

  bool _shouldReportInterpolation(StringInterpolation node) {
    final parts = node.elements.whereType<InterpolationExpression>().toList();
    if (parts.length < 2 && !config.strictMode) return false;

    var hasCivil = false;
    var hasInstant = false;
    for (final part in parts) {
      final signal = _TimeSignalCollector.collect(part.expression);
      hasCivil = hasCivil || signal.hasCivil;
      hasInstant = hasInstant || signal.hasInstant;
      if (hasCivil && hasInstant) return true;
    }

    return false;
  }

  bool _shouldReportInvocation(MethodInvocation node) {
    if (_isPassthroughInvocation(node)) return false;

    final targetSignal = node.target == null
        ? _TimeSignal.empty()
        : _TimeSignalCollector.collect(node.target!);
    final argumentSignals = node.argumentList.arguments
        .map((argument) =>
            _TimeSignalCollector.collect(_unwrapArgument(argument)))
        .toList();

    final hasCivil =
        targetSignal.hasCivil || argumentSignals.any((s) => s.hasCivil);
    final hasInstant =
        targetSignal.hasInstant || argumentSignals.any((s) => s.hasInstant);
    if (!hasCivil || !hasInstant) return false;

    if (config.strictMode) return true;

    if (_riskyInvocationMethods.contains(node.methodName.name)) return true;

    return false;
  }

  bool _isPassthroughInvocation(MethodInvocation node) {
    if (node.target == null) return false;
    if (node.argumentList.arguments.isEmpty) return false;

    final isPlainArgs = node.argumentList.arguments.every((argument) {
      final expr = _unwrapArgument(argument);
      return expr is SimpleIdentifier;
    });
    if (!isPlainArgs) return false;

    final parent = node.parent;
    if (parent is ReturnStatement || parent is ExpressionStatement) {
      return true;
    }

    if (parent is AwaitExpression) {
      final awaitParent = parent.parent;
      return awaitParent is ReturnStatement ||
          awaitParent is ExpressionStatement;
    }

    return false;
  }

  Expression _unwrapArgument(Expression expression) {
    if (expression is NamedExpression) return expression.expression;
    return expression;
  }

  bool _isRiskyBinaryOperator(String operator) {
    return _riskyBinaryOperators.contains(operator);
  }

  static const _riskyBinaryOperators = {
    '+',
    '==',
    '!=',
    '>',
    '<',
    '>=',
    '<=',
  };

  static const _riskyInvocationMethods = {
    'compareTo',
    'difference',
    'isBefore',
    'isAfter',
    'isAtSameMomentAs',
    'format',
    'merge',
    'combine',
  };
}

class NoCivilUtcMixWithoutHelperConfig {
  const NoCivilUtcMixWithoutHelperConfig({
    this.helperWhitelist = const [],
    this.includeGlobs = _defaultIncludes,
    this.excludeGlobs = _defaultExcludes,
    this.strictMode = false,
  });

  factory NoCivilUtcMixWithoutHelperConfig.fromJson(Map<String, Object?> json) {
    return NoCivilUtcMixWithoutHelperConfig(
      helperWhitelist: readStringListOption(json, 'helper_whitelist'),
      includeGlobs: readStringListOption(
        json,
        'include_globs',
        fallback: _defaultIncludes,
      ),
      excludeGlobs: readStringListOption(
        json,
        'exclude_globs',
        fallback: _defaultExcludes,
      ),
      strictMode: readBoolOption(json, 'strict_mode', fallback: false),
    );
  }

  static const _defaultIncludes = [
    '**/mappers/**',
    '**/formatters/**',
    '**/adapters/**',
  ];

  static const _defaultExcludes = [
    '**/test/**',
    '**/tests/**',
    '**/*_test.dart',
  ];

  final List<String> helperWhitelist;
  final List<String> includeGlobs;
  final List<String> excludeGlobs;
  final bool strictMode;

  bool matchesPath(String normalizedPath) {
    if (!matchesAnyGlob(normalizedPath, includeGlobs)) return false;
    if (excludeGlobs.isNotEmpty &&
        matchesAnyGlob(normalizedPath, excludeGlobs)) {
      return false;
    }
    return true;
  }

  bool isInsideWhitelistedHelper(AstNode node) {
    if (helperWhitelist.isEmpty) return false;

    AstNode? current = node;
    while (current != null) {
      if (current is MethodInvocation) {
        final names = _methodCandidates(current);
        if (names.any((name) => matchesAnyWildcard(name, helperWhitelist))) {
          return true;
        }
      }
      current = current.parent;
    }

    return false;
  }

  List<String> _methodCandidates(MethodInvocation node) {
    final methodName = node.methodName.name;
    final target = node.target;
    if (target == null) return [methodName];

    final source = target.toSource();
    final compactSource = source.replaceAll(' ', '');
    return [
      methodName,
      '$source.$methodName',
      '$compactSource.$methodName',
    ];
  }
}

class _TimeSignalCollector extends RecursiveAstVisitor<void> {
  _TimeSignalCollector();

  static _TimeSignal collect(AstNode node) {
    final collector = _TimeSignalCollector();
    node.accept(collector);
    return collector._signal;
  }

  final _signal = _TimeSignal();

  static final _dateOnlyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _isoInstantPattern = RegExp(
      r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(\.\d+)?(Z|[+-]\d{2}:?\d{2})$');

  static const _instantMethodSignals = {
    'toUtc',
    'toLocal',
    'millisecondsSinceEpoch',
    'microsecondsSinceEpoch',
    'isUtc',
    'toIso8601String',
    'fromMillisecondsSinceEpoch',
    'fromMicrosecondsSinceEpoch',
    'hour',
    'minute',
    'second',
    'millisecond',
    'microsecond',
  };

  static const _civilNameSignals = {
    'fecha',
    'civil',
    'date',
    'day',
    'dia',
    'localdate',
    'dateonly',
  };

  static const _instantNameSignals = {
    'timestamp',
    'datetime',
    'utc',
    'timestamptz',
    'instant',
    'epoch',
    'time',
    'hour',
    'minute',
    'second',
  };

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);
    _signal.merge(_classifyName(node.name));
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    final methodName = node.methodName.name;
    _signal.merge(_classifyName(methodName));

    if (_instantMethodSignals.contains(methodName)) {
      _signal.hasInstant = true;
    }

    final target = node.target;
    if (target is Identifier && target.name == 'DateTime') {
      if (methodName == 'now' || methodName == 'utc') {
        _signal.hasInstant = true;
      }

      if (methodName == 'parse' && node.argumentList.arguments.isNotEmpty) {
        final parsedArg = _unwrapArgument(node.argumentList.arguments.first);
        _signal.merge(_classifyParseArgument(parsedArg));
      }
    }
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    super.visitPropertyAccess(node);
    _signal.merge(_classifyName(node.propertyName.name));
    if (_instantMethodSignals.contains(node.propertyName.name)) {
      _signal.hasInstant = true;
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);

    if (node.constructorName.type.name.lexeme != 'DateTime') return;

    final constructor = node.constructorName.name?.name;
    if (constructor == 'utc' ||
        constructor == 'now' ||
        constructor == 'fromMillisecondsSinceEpoch' ||
        constructor == 'fromMicrosecondsSinceEpoch') {
      _signal.hasInstant = true;
      return;
    }

    final positional =
        node.argumentList.arguments.whereType<Expression>().where((arg) {
      return arg is! NamedExpression;
    }).length;

    final hasClockParts =
        node.argumentList.arguments.whereType<NamedExpression>().any((named) {
      const clockParts = {
        'hour',
        'minute',
        'second',
        'millisecond',
        'microsecond'
      };
      return clockParts.contains(named.name.label.name);
    });

    if (constructor == null && positional <= 3 && !hasClockParts) {
      _signal.hasCivil = true;
      return;
    }

    _signal.hasInstant = true;
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    super.visitPrefixedIdentifier(node);
    _signal.merge(_classifyName(node.identifier.name));
    _signal.merge(_classifyName(node.prefix.name));
  }

  _TimeSignal _classifyName(String raw) {
    final signal = _TimeSignal();
    final words = _splitWords(raw);

    final hasDate = words.contains('date');
    final hasTime = words.contains('time');
    final hasDateTime = words.contains('datetime') || (hasDate && hasTime);

    if (hasDateTime || words.any(_instantNameSignals.contains)) {
      signal.hasInstant = true;
    }

    final hasCivilName = words.any(_civilNameSignals.contains);
    if (hasCivilName && !signal.hasInstant) {
      signal.hasCivil = true;
    }

    return signal;
  }

  _TimeSignal _classifyParseArgument(Expression argument) {
    if (argument is SimpleStringLiteral) {
      final content = argument.value.trim();
      if (_dateOnlyPattern.hasMatch(content)) {
        return _TimeSignal(hasCivil: true);
      }
      if (_isoInstantPattern.hasMatch(content)) {
        return _TimeSignal(hasInstant: true);
      }
    }

    if (argument is SimpleIdentifier) {
      return _classifyName(argument.name);
    }

    return _TimeSignal.empty();
  }

  Expression _unwrapArgument(Expression expression) {
    if (expression is NamedExpression) {
      return expression.expression;
    }
    return expression;
  }

  Set<String> _splitWords(String value) {
    final normalized = value.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    );

    return normalized
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
  }
}

class _TimeSignal {
  _TimeSignal({
    this.hasCivil = false,
    this.hasInstant = false,
  });

  _TimeSignal.empty()
      : hasCivil = false,
        hasInstant = false;

  bool hasCivil;
  bool hasInstant;

  void merge(_TimeSignal other) {
    hasCivil = hasCivil || other.hasCivil;
    hasInstant = hasInstant || other.hasInstant;
  }
}

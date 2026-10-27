import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:dart_architecture_lints/generated_skipping_dart_lint_rule.dart';
import 'package:dart_architecture_lints/avoid_hardcoded_strings.dart';
import 'package:dart_architecture_lints/enforce_final_variables.dart';
import 'package:dart_architecture_lints/method_order_rule.dart';
import 'package:dart_architecture_lints/no_bang_operator.dart';
import 'package:dart_architecture_lints/no_datetime_now.dart';
import 'package:dart_architecture_lints/no_late_keyword.dart';
import 'package:dart_architecture_lints/require_explicit_types.dart';
import 'package:dart_architecture_lints/variable_name_should_match_class_name.dart';
import 'package:dart_architecture_lints/viewmodels_call_super_dispose.dart';
import 'package:dart_architecture_lints/one_class_per_file.dart';
import 'package:dart_architecture_lints/usecases_follow_pattern.dart';
import 'package:dart_architecture_lints/viewmodels_no_buildcontext.dart';
import 'package:dart_architecture_lints/require_keys_in_lists.dart';
import 'package:dart_architecture_lints/no_external_dependencies_in_domain.dart';
import 'package:dart_architecture_lints/enforce_utc_dates.dart';
import 'package:dart_architecture_lints/no_direct_internet_calls.dart';
import 'package:dart_architecture_lints/no_static_map_controllers.dart';
import 'package:dart_architecture_lints/mixin_no_state_ownership.dart';
import 'package:dart_architecture_lints/viewmodels_no_flutter_types.dart';
import 'package:dart_architecture_lints/no_result_throw.dart';
import 'package:dart_architecture_lints/uistate_must_call_super_dispose.dart';
import 'package:dart_architecture_lints/multiprovider_order.dart';
import 'package:dart_architecture_lints/domain_entities_must_use_freezed.dart';
import 'package:dart_architecture_lints/domain_values_shallow_immutable.dart';
import 'package:dart_architecture_lints/no_serialization_in_entities.dart';
import 'package:dart_architecture_lints/models_must_have_json_serialization.dart';
import 'package:dart_architecture_lints/usecases_extend_base_usecase.dart';
import 'package:dart_architecture_lints/viewmodels_extend_base_viewmodel.dart';
import 'package:dart_architecture_lints/repository_methods_return_result.dart';
import 'package:dart_architecture_lints/streamcontroller_must_close.dart';
import 'package:dart_architecture_lints/datasources_return_result.dart';
import 'package:dart_architecture_lints/avoid_unawaited.dart';
import 'package:dart_architecture_lints/avoid_unawaited_ignore_without_reason.dart';
import 'package:dart_architecture_lints/avoid_async_in_provider_create.dart';
import 'package:dart_architecture_lints/avoid_async_wrapper_hides_unawaited.dart';
import 'package:dart_architecture_lints/no_business_logic_in_widgets.dart';
import 'package:dart_architecture_lints/no_direct_error_logging_in_data_domain.dart';
import 'package:dart_architecture_lints/logger_context_must_be_structured.dart';
import 'package:dart_architecture_lints/logger_context_matches_scope.dart';
import 'package:dart_architecture_lints/no_sensitive_data_in_log_metadata.dart';
import 'package:dart_architecture_lints/top_level_screens_must_use_base_contract.dart';
import 'package:dart_architecture_lints/no_raw_exception_message_to_user.dart';
import 'package:dart_architecture_lints/no_exception_message_passthrough.dart';
import 'package:dart_architecture_lints/app_exception_must_define_code.dart';
import 'package:dart_architecture_lints/no_device_local_in_presentation.dart';
import 'package:dart_architecture_lints/no_civil_utc_mix_without_helper.dart';
import 'package:dart_architecture_lints/avoid_scattered_401_handling.dart';
import 'package:dart_architecture_lints/no_domain_entities_in_presentation_ui.dart';
import 'package:dart_architecture_lints/no_utc_time_format_without_empresa_helper.dart';
import 'package:dart_architecture_lints/no_hardcoded_color_literal.dart';
import 'package:dart_architecture_lints/no_hardcoded_border_radius.dart';
import 'package:dart_architecture_lints/overlay_lifecycle_context_safety.dart';

/// The analyzer plugin: registers every rule, enabled by default.
///
/// A consumer disables a rule under `plugins: dart_architecture_lints:
/// diagnostics:` in its `analysis_options.yaml`.
class DartArchitectureLintsPlugin extends Plugin {
  @override
  String get name => 'dart_architecture_lints';

  @override
  void register(PluginRegistry registry) {
    for (final rule in createRules()) {
      registry.registerWarningRule(rule);
    }
  }
}

/// New instances of every registered rule, in registration order.
///
/// Rule options are fixed: each rule runs with its built-in defaults.
List<GeneratedSkippingDartLintRule> createRules() => [
  NoBangOperatorLint(),
  NoLateKeywordLint(),
  EnforceFinalVariablesLint(),
  VariableNameShouldMatchClassName(),
  MethodOrderRule(),
  AvoidHardcodedStrings(),
  NoDateTimeNowLint(),
  ViewModelsCallSuperDisposeLint(),
  OneClassPerFileLint(),
  UseCasesFollowPatternLint(),
  ViewModelsNoBuildContextLint(),
  RequireKeysInListsLint(),
  NoExternalDependenciesInDomainLint(),
  EnforceUtcDatesLint(),
  NoDirectInternetCallsLint(),
  NoDeviceLocalInPresentationLint(),
  NoCivilUtcMixWithoutHelperLint(),
  // New critical rules (error level)
  NoStaticMapControllersLint(),
  MixinNoStateOwnershipLint(),
  ViewModelsNoFlutterTypesLint(),
  NoResultThrowLint(),
  // New high-priority rules (warning level)
  UiStateMustCallSuperDisposeLint(),
  MultiProviderOrderLint(),
  // Phase 1A: Domain/Data layer foundation rules
  // Opt-in Freezed convention and generator-independent shallow check
  DomainEntitiesMustUseFreezed(),
  DomainValuesShallowImmutable(),
  NoSerializationInEntities(),
  ModelsMustHaveJsonSerialization(),
  // Phase 1B: Obligatory patterns
  UseCasesExtendBaseUseCase(),
  // Phase 2: Contracts and lifecycle
  ViewModelsExtendBaseViewModel(),
  RepositoryMethodsReturnResult(),
  StreamControllerMustClose(),
  RequireExplicitTypes(),
  // Phase 3: Completeness
  DataSourcesReturnResult(),
  NoBusinessLogicInWidgets(),
  // Unawaited governance
  AvoidUnawaitedLint(),
  AvoidUnawaitedIgnoreWithoutReasonLint(),
  AvoidAsyncInProviderCreateLint(),
  AvoidAsyncWrapperHidesUnawaitedLint(),
  // Logging governance
  NoDirectErrorLoggingInDataDomainLint(),
  LoggerContextMustBeStructuredLint(),
  LoggerContextMatchesScopeLint(),
  NoSensitiveDataInLogMetadataLint(),
  // Exception message governance (i18n safety)
  NoRawExceptionMessageToUser(),
  NoExceptionMessagePassthrough(),
  AppExceptionMustDefineCode(),
  AvoidScattered401HandlingLint(),
  // Screen base contract enforcement
  TopLevelScreensMustUseBaseContract(),
  NoDomainEntitiesInPresentationUiLint(),
  // Timezone display safety
  NoUtcTimeFormatWithoutEmpresaHelperLint(),
  // Presentation color tokens
  NoHardcodedColorLiteralLint(),
  // Presentation spacing tokens
  NoHardcodedBorderRadiusLint(),
  // Overlay lifecycle/context safety
  OverlayLifecycleContextSafetyLint(),
];

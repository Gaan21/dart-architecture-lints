import 'package:custom_lint_builder/custom_lint_builder.dart';
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

/// Creates an instance of the custom lint plugin.
PluginBase createPlugin() => _MyCustomLints();

class _MyCustomLints extends PluginBase {
  /// Returns the list of lint rules applied by this plugin.
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const NoBangOperatorLint(),
        const NoLateKeywordLint(),
        const EnforceFinalVariablesLint(),
        const VariableNameShouldMatchClassName(),
        const MethodOrderRule(),
        const AvoidHardcodedStrings(),
        const NoDateTimeNowLint(),
        const ViewModelsCallSuperDisposeLint(),
        const OneClassPerFileLint(),
        const UseCasesFollowPatternLint(),
        const ViewModelsNoBuildContextLint(),
        const RequireKeysInListsLint(),
        const NoExternalDependenciesInDomainLint(),
        const EnforceUtcDatesLint(),
        const NoDirectInternetCallsLint(),
        NoDeviceLocalInPresentationLint.fromConfigs(configs),
        NoCivilUtcMixWithoutHelperLint.fromConfigs(configs),
        // New critical rules (error level)
        const NoStaticMapControllersLint(),
        const MixinNoStateOwnershipLint(),
        const ViewModelsNoFlutterTypesLint(),
        const NoResultThrowLint(),
        // New high-priority rules (warning level)
        const UiStateMustCallSuperDisposeLint(),
        const MultiProviderOrderLint(),
        // Phase 1A: Domain/Data layer foundation rules
        const DomainEntitiesMustUseFreezed(),
        const NoSerializationInEntities(),
        const ModelsMustHaveJsonSerialization(),
        // Phase 1B: Obligatory patterns
        const UseCasesExtendBaseUseCase(),
        // Phase 2: Contracts and lifecycle
        const ViewModelsExtendBaseViewModel(),
        const RepositoryMethodsReturnResult(),
        const StreamControllerMustClose(),
        const RequireExplicitTypes(),
        // Phase 3: Completeness
        const DataSourcesReturnResult(),
        const NoBusinessLogicInWidgets(),
        // Unawaited governance
        const AvoidUnawaitedLint(),
        const AvoidUnawaitedIgnoreWithoutReasonLint(),
        const AvoidAsyncInProviderCreateLint(),
        const AvoidAsyncWrapperHidesUnawaitedLint(),
        // Logging governance
        const NoDirectErrorLoggingInDataDomainLint(),
        const LoggerContextMustBeStructuredLint(),
        const LoggerContextMatchesScopeLint(),
        const NoSensitiveDataInLogMetadataLint(),
        // Exception message governance (i18n safety)
        const NoRawExceptionMessageToUser(),
        const NoExceptionMessagePassthrough(),
        const AppExceptionMustDefineCode(),
        const AvoidScattered401HandlingLint(),
        // Screen base contract enforcement
        const TopLevelScreensMustUseBaseContract(),
        NoDomainEntitiesInPresentationUiLint.fromConfigs(configs),
        // Timezone display safety
        NoUtcTimeFormatWithoutEmpresaHelperLint.fromConfigs(configs),
        // Presentation color tokens
        NoHardcodedColorLiteralLint.fromConfigs(configs),
        // Presentation spacing tokens
        NoHardcodedBorderRadiusLint.fromConfigs(configs),
      ];
}

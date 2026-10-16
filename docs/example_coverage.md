# Documentation example coverage

Generated from live diagnostic IDs and the actual rule documents.

## Executed full-profile sources

`test/profile_fixture_test.dart` resolves every source below, runs all 48 selected
rules against it, and executes the runnable entry. These are the only canonical
full-profile sources; this is not behavior coverage of all 51 diagnostics.

- [examples/architecture/lib/presentation/viewModels/event_owner.dart](../examples/architecture/lib/presentation/viewModels/event_owner.dart)

## Rule-document audit

Every row names the exact isolated diagnostic contract. Dart fences include
positive/negative contrasts and partial setup snippets. None is represented as a
compiled full-profile fixture unless it exactly references checked source.
Counts audit the actual files, not a second manually maintained rule catalogue.
Explicit annotations in isolated sketches may illustrate legacy strict typing;
they do not override selective locals in the architecture recommendation. Partial
framework/service sketches can omit declarations and retain names/order relevant
only to their isolated contrast. Do not paste them as full-profile implementations.
The static-map ownership sketch additionally has a source-extracted style/order
regression in `test/doc_sketch_regression_test.dart` using original local stand-ins.

| Diagnostic / document | Dart fences | Local contract | Full-profile path |
|-----------------------|-------------|----------------|-------------------|
| [`app_exception_must_define_code`](rules/app_exception_must_define_code.md) | 7 | Isolated `app_exception_must_define_code`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`avoid_async_in_provider_create`](rules/avoid_async_in_provider_create.md) | 5 | Isolated `avoid_async_in_provider_create`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`avoid_async_wrapper_hides_unawaited`](rules/avoid_async_wrapper_hides_unawaited.md) | 6 | Isolated `avoid_async_wrapper_hides_unawaited`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`avoid_hardcoded_strings`](rules/avoid_hardcoded_strings.md) | 3 | Isolated `avoid_hardcoded_strings`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`avoid_scattered_401_handling`](rules/avoid_scattered_401_handling.md) | 1 | Isolated `avoid_scattered_401_handling`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`avoid_unawaited`](rules/avoid_unawaited.md) | 8 | Isolated `avoid_unawaited`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`avoid_unawaited_ignore_without_reason`](rules/avoid_unawaited_ignore_without_reason.md) | 1 | Isolated `avoid_unawaited_ignore_without_reason`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`datasources_return_result`](rules/datasources_return_result.md) | 8 | Isolated `datasources_return_result`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`domain_entities_must_use_freezed`](rules/domain_entities_must_use_freezed.md) | 8 | Isolated `domain_entities_must_use_freezed`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`enforce_final_variables`](rules/enforce_final_variables.md) | 0 | Prose only | [Checked sources](../examples/architecture/README.md) |
| [`enforce_utc_dates`](rules/enforce_utc_dates.md) | 0 | Prose only | [Checked sources](../examples/architecture/README.md) |
| [`logger_context_matches_scope`](rules/logger_context_matches_scope.md) | 0 | Prose only | [Checked sources](../examples/architecture/README.md) |
| [`logger_context_must_be_structured`](rules/logger_context_must_be_structured.md) | 5 | Isolated `logger_context_must_be_structured`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`method_order`](rules/method_order.md) | 0 | Prose only | [Checked sources](../examples/architecture/README.md) |
| [`mixin_no_state_ownership`](rules/mixin_no_state_ownership.md) | 3 | Isolated `mixin_no_state_ownership`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`models_must_have_json_serialization`](rules/models_must_have_json_serialization.md) | 10 | Isolated `models_must_have_json_serialization`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`multiprovider_order`](rules/multiprovider_order.md) | 0 | Prose only | [Checked sources](../examples/architecture/README.md) |
| [`no_bang_operator`](rules/no_bang_operator.md) | 1 | Isolated `no_bang_operator`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_business_logic_in_widgets`](rules/no_business_logic_in_widgets.md) | 12 | Isolated `no_business_logic_in_widgets`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_civil_utc_mix_without_helper`](rules/no_civil_utc_mix_without_helper.md) | 1 | Isolated `no_civil_utc_mix_without_helper`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_device_local_in_presentation`](rules/no_device_local_in_presentation.md) | 1 | Isolated `no_device_local_in_presentation`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_direct_error_logging_in_data_domain`](rules/no_direct_error_logging_in_data_domain.md) | 5 | Isolated `no_direct_error_logging_in_data_domain`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_direct_internet_calls`](rules/no_direct_internet_calls.md) | 8 | Isolated `no_direct_internet_calls`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_domain_entities_in_presentation_ui`](rules/no_domain_entities_in_presentation_ui.md) | 4 | Isolated `no_domain_entities_in_presentation_ui`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_exception_message_passthrough`](rules/no_exception_message_passthrough.md) | 8 | Isolated `no_exception_message_passthrough`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_external_dependencies_in_domain`](rules/no_external_dependencies_in_domain.md) | 8 | Isolated `no_external_dependencies_in_domain`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_hardcoded_border_radius`](rules/no_hardcoded_border_radius.md) | 1 | Isolated `no_hardcoded_border_radius`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_hardcoded_color_literal`](rules/no_hardcoded_color_literal.md) | 1 | Isolated `no_hardcoded_color_literal`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_late_keyword`](rules/no_late_keyword.md) | 3 | Isolated `no_late_keyword`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_local_datetime_constructors`](rules/no_local_datetime_constructors.md) | 0 | Prose only | [Checked sources](../examples/architecture/README.md) |
| [`no_raw_exception_message_to_user`](rules/no_raw_exception_message_to_user.md) | 7 | Isolated `no_raw_exception_message_to_user`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_result_throw`](rules/no_result_throw.md) | 3 | Isolated `no_result_throw`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_sensitive_data_in_log_metadata`](rules/no_sensitive_data_in_log_metadata.md) | 5 | Isolated `no_sensitive_data_in_log_metadata`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_serialization_in_entities`](rules/no_serialization_in_entities.md) | 9 | Isolated `no_serialization_in_entities`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_static_map_controllers`](rules/no_static_map_controllers.md) | 3 | Isolated `no_static_map_controllers`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`no_utc_time_format_without_empresa_helper`](rules/no_utc_time_format_without_empresa_helper.md) | 7 | Isolated `no_utc_time_format_without_empresa_helper`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`one_class_per_file`](rules/one_class_per_file.md) | 9 | Isolated `one_class_per_file`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`overlay_lifecycle_context_safety`](rules/overlay_lifecycle_context_safety.md) | 5 | Isolated `overlay_lifecycle_context_safety`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`repository_methods_return_result`](rules/repository_methods_return_result.md) | 7 | Isolated `repository_methods_return_result`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`require_explicit_types`](rules/require_explicit_types.md) | 1 | Isolated `require_explicit_types`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`require_keys_in_lists`](rules/require_keys_in_lists.md) | 0 | Prose only | [Checked sources](../examples/architecture/README.md) |
| [`streamcontroller_must_close`](rules/streamcontroller_must_close.md) | 0 | Prose only | [Checked sources](../examples/architecture/README.md) |
| [`top_level_screens_must_use_base_contract`](rules/top_level_screens_must_use_base_contract.md) | 8 | Isolated `top_level_screens_must_use_base_contract`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`uistate_must_call_super_dispose`](rules/uistate_must_call_super_dispose.md) | 2 | Isolated `uistate_must_call_super_dispose`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`usecases_extend_base_usecase`](rules/usecases_extend_base_usecase.md) | 10 | Isolated `usecases_extend_base_usecase`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`usecases_follow_pattern`](rules/usecases_follow_pattern.md) | 6 | Isolated `usecases_follow_pattern`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`variable_name_should_contain_class_name`](rules/variable_name_should_contain_class_name.md) | 0 | Prose only | [Checked sources](../examples/architecture/README.md) |
| [`viewmodels_call_super_dispose`](rules/viewmodels_call_super_dispose.md) | 4 | Isolated `viewmodels_call_super_dispose`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`viewmodels_extend_base_viewmodel`](rules/viewmodels_extend_base_viewmodel.md) | 6 | Isolated `viewmodels_extend_base_viewmodel`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`viewmodels_no_buildcontext`](rules/viewmodels_no_buildcontext.md) | 9 | Isolated `viewmodels_no_buildcontext`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |
| [`viewmodels_no_flutter_types`](rules/viewmodels_no_flutter_types.md) | 3 | Isolated `viewmodels_no_flutter_types`; not compiled acceptance | [Checked sources](../examples/architecture/README.md) |

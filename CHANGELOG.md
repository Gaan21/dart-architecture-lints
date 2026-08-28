# Changelog

## 0.0.6 — first public release

Initial public distribution of the rule set.

- Timezone safety: `no_utc_time_format_without_empresa_helper`,
  `no_civil_utc_mix_without_helper` and `no_device_local_in_presentation`, with
  configurable path globs and approved-wrapper lists, and 44 automated tests.
- Layer boundaries: domain purity, `Result`-returning repositories and data
  sources, view-model constraints, presentation-model boundaries.
- Lifecycle: `super.dispose()` contracts, stream controller closure.
- Logging and error governance, including a rule that keeps credentials and
  tokens out of log metadata and messages.
- Unawaited-future governance.
- The rule catalogue in the README is generated from the plugin's registration
  list rather than maintained by hand.

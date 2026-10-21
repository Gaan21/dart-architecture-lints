# Maintainer instructions

- Scope: Dart/Flutter static-analysis rules. Keep written policy and actual
  diagnostic behavior coherent; guidance and the Python delivery CLI stay separate.
- When asked about pending work, read `docs/deferred-guidance-alignment.md`.
  Report low-priority proposals as pending, not implemented or urgent by default.
- For guidance/lint alignment work, also read the maintained `agent-guides`
  follow-up linked there. Review policy impact in both directions for additions,
  changes and removals; document actual coverage, exceptions and residual review.
- Inspect Git status/diff before edits and preserve existing work. Use focused
  positive/negative tests for detector changes. Do not claim semantic guarantees
  from annotation spelling, class names or signatures alone.
- No automatic consumer configuration changes, architecture migration, staging,
  commits, pushes or releases. Obtain explicit authorization for those actions.
- Do not copy private product evidence into this public repository. Use concise
  English documentation and keep new files below 500 lines.

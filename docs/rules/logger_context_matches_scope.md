<!-- example-scope: isolated logger_context_matches_scope -->

> **Example contract: `logger_context_matches_scope` only.** Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md) for executed whole-profile acceptance.

# logger_context_matches_scope

Checks a literal logging-context argument against the enclosing named member.
Expected context is `Type.member`, removing one leading `_` and a trailing
`Internal` from member names. Named constructors, class/mixin/enum/extension
members are supported; top-level functions and unnamed constructors are skipped.

Legacy scope and receiver matching remain the defaults. Portable projects should
explicitly configure `include_globs`, `logger_names`, `methods` and
`context_argument`; `exclude_globs` can narrow scope further. The generated
architecture sample provides generic logger names, not an application API.

Only existing simple literal context arguments are checked; the rule does not
require a missing argument, validate interpolated expressions or enforce error
reporting ownership. Separate logging governance rules retain those contracts.

See [exact options and default semantics](../configuration.md).

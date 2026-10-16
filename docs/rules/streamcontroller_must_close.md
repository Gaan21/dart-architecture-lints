<!-- example-scope: isolated streamcontroller_must_close -->

> **Example contract: `streamcontroller_must_close` only.** Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md) for executed whole-profile acceptance.

# streamcontroller_must_close

Checks locally owned StreamController fields in the existing view-model path or
base-class scope, including inferred types and indirect base classes. Each field
must close on all modeled normal exits from `dispose`. Closing one of multiple
declared controllers does not satisfy the others.

Resolved identity distinguishes `this.field` from a same-named local. Both
branches must close, an early return must be covered, and `finally` runs on
returns. A catch can be entered before cleanup succeeds. Same-instance local
helper bodies are followed with recursion protection; asynchronous helpers must
be awaited to establish closure.

Constructor injection and simple identifier/property initializers are treated as
borrowed/unknown ownership. Do not close another owner's controller just to
satisfy a lint. Constructor/field construction and factory calls are treated as
owned. Inherited resources are checked at their declaration rather than demanding
a second close in each subclass.

See [resource limits](../configuration.md): inherited helper bodies, alias/late
ownership transfers, cascades and arbitrary control flow are not proved. The
check is conservative and does not prove close completion or super-call order.

The tests include valid borrowed resources and local cleanup, and failures for
missing cleanup, partial branches, early returns, shadowing and catch exits.

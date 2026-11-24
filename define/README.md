# Define

`define/` owns host-independent initialization protocols and construction helpers,
formerly in extension and the mixed widget layer. It does not require mp.
`require 'define'` collects the static API; scope-bound imports and bind belong to
each DefineSession and are restored after flat imports.

- `src/session.lua`: phase machine, scopes, successful-first payloads and transactions.
- `src/modules.lua`: package descriptors, exact multi-level registration, protection,
  transactional publication and scoped loaders.
- `src/sandbox.lua`: restricted environments and portable chunk loading.
- `src/dsl.lua`, `src/bind.lua`: class factories and initialization bind facade.
- `src/slot.lua`: SlotSpec/Wrap, contributions and fresh CompositionAssembler output.
- `src/builder.lua`: SlotBuilder/call_slot, reusing framework callback/result validation.

Each failed payload rolls back all contributions and publications without consuming
its scope. The first successful payload commits; later payloads warn and are ignored.
At seal the host assembles once before mount. This protocol has no runtime unbind,
scope shutdown, mounted-tree rollback, root manager or source hot reload.
Assembly snapshots initialized Widget data without invoking constructors again.
Direct and dict instance storage are supported through the existing class identity
and the actual metatable; callbacks and class/value objects retain
identity, while ordinary configuration tables and child arrays are copied.

`import` injects exports; `import_as` and its `require` alias return a shallow package
without environment injection. They preserve nested/class/array identity and run loaders within the
active transaction. Multi-level names resolve exact registered packages, not fields.
Protecting a parent also protects unpublished descendant names.

`package_catalog.collect()` lists Define's root and all runtime sources. The root
uses framework export to collect members, including sandbox `load_chunk`/`new_env`;
it does not attach the sandbox source table. Use `import_as('define.sandbox')` or
`require 'define.src.sandbox'` for that independent module. Framework export creates
static package descriptors; ModuleRegistry adds scoped loaders and owns transactional
publication, protection and payload visibility.

`host/package_catalog.lua` joins the three owning catalogs; `host/builtins.lua` exposes
`new_widget`/`new_state` and selected Lua utilities, including `math` and `table`.
Components and framework values are imported from their owning packages.
Builtins are injected as-is: library tables are shared, while assignments to names
stay in one scope. The external `std` package is registered by `host/mpv_define.lua`,
without adding a builtin, and remains importable when defaults are overridden.
DefineSession supplies the five protocol functions and host adds `print`;
custom builtin overrides retain their replacement semantics.
Host mp/player facades provide owned disposable subscriptions.
Static source modules and collectors remain usable without registration.

Types belong to `elxosc.mod.define.*` and `elxosc.define.*`. Class factory name
templates bind declared extension subclasses and keep their constructor signatures;
the runtime class names remain caller-controlled. The [meta entry](../meta/README.md)
describes payload names through `elxosc.meta.Builtins` table members and package/type
declarations. Metadata does not declare editor globals or replace Lua's `require`.

See [host protocol](../dev/design/HOST.md) and [player composition](../dev/design/PLAYER.md).

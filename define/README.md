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

`import` injects exports; `import_as` returns a shallow package without environment
injection. Both preserve nested/class/array identity and run loaders within the
active transaction. Multi-level names resolve exact registered packages, not fields.
Protecting a parent also protects unpublished descendant names.

`package_catalog.collect()` lists Define's root and all runtime sources. The root
uses framework export to collect members, including sandbox `load_chunk`/`new_env`;
it does not attach the sandbox source table. Use `import_as('define.sandbox')` or
`require 'define.src.sandbox'` for that independent module. Framework export creates
static package descriptors; ModuleRegistry adds scoped loaders and owns transactional
publication, protection and payload visibility.

`host/package_catalog.lua` joins the three owning catalogs; `host/builtins.lua` explicitly
selects 115 default fields. Host mp/player facades provide owned disposable subscriptions.
Static source modules and collectors remain usable without registration.

Types belong to `elxosc.mod.define.*` and `elxosc.define.*`. Class factory name
templates bind declared extension subclasses and keep their constructor signatures;
the runtime class names remain caller-controlled. The [meta entry](../meta/README.md)
provides imports, default globals and extension package/type declarations for editors.

See [host protocol](../dev/design/HOST.md) and [player composition](../dev/design/PLAYER.md).

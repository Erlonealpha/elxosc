# Libraries and Define

`libs/` provides host-independent services used to construct and extend Widget
trees from controlled Lua sources. It must not import `mp`.

## Public entry points

- `sandbox.lua` — restricted environments and portable chunk loading.
- `modules.lua` — data modules, scope-aware loaders, and protected names.
- `define.lua` — Define phase machine, scopes, `import`/`mod`/`bind` builtins.
- `dsl.lua` — `new_widget`, `new_state`, and builtins assembly helpers.

Define is an initialization-time construction protocol. The registry does not own
runtime unbind, scope shutdown, tree rollback, root rebuild, or navigation. Host
services are injected facades, not a global raw mpv table.

See [host](../dev/design/HOST.md) and [widgets](../dev/design/WIDGETS.md).

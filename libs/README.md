# Libraries and Define

`libs/` provides host-independent services used to construct and extend Widget
trees from controlled Lua sources. It must not import `mp`.

## Public entry points

- `sandbox.lua` — restricted environments and portable chunk loading.
- `modules.lua` — data modules, scope-aware loaders, and protected names.
- `define.lua` — Define phase machine, scopes, `import`/`mod`/`bind` builtins.
- `dsl.lua` — `new_widget`, `new_state`, and builtins assembly helpers.

Define is the sole extension-content ingress and currently an initialization-time
construction protocol. It transports content; each extension owns its runtime
behavior. The registry does not own runtime unbind, scope shutdown, tree rollback,
root rebuild, or navigation. Host services are injected facades, not a raw mpv table.

Planned Pages APIs let Define content contribute pages/regions; config/API hot updates
deliver data and events without becoming a second content ingress or reloading code.

See [host](../dev/design/HOST.md), [widgets](../dev/design/WIDGETS.md), and
[player application](../dev/design/PLAYER.md).

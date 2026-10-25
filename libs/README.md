# Libraries and Define

`libs/` provides host-independent services used to construct and extend Widget
trees from controlled Lua sources. It must not import `mp`.

## Public entry points

- `sandbox.lua` — restricted environments and portable chunk loading.
- `modules.lua` — data modules, scope-aware loaders, and protected names.
- `define.lua` — Define phase machine, scopes, transactional payloads and
  `import`/`mod`/`bind` builtins.
- `dsl.lua` — `new_widget`, `new_state`, and builtins assembly helpers.

Define is the sole extension-content ingress and currently an initialization-time
construction protocol. Each payload stages its contributions and module publishes;
only a successful payload commits them. A failed payload contributes nothing and
does not consume its scope. At seal, the host calls one assembler to produce a
fresh Widget description, after which the runtime binding owns only mount/update/
dispose. There is no runtime unbind, scope shutdown, tree rollback, root rebuild,
or navigation protocol. Host services are injected facades, not a raw mpv table.

Host `mp.on_prop`, `mp.on_event` and scope message subscriptions return idempotent
disposers. `MpDefine:shutdown()` releases Define-owned host subscriptions; config
and PlayerStore updates remain data/event updates and never re-run Define source.

Planned Pages APIs let Define content contribute pages/regions; config/API hot updates
deliver data and events without becoming a second content ingress or reloading code.

See [host](../dev/design/HOST.md), [widgets](../dev/design/WIDGETS.md), and
[player application](../dev/design/PLAYER.md).

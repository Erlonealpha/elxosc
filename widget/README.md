# Widget

`widget/` owns the immutable declaration layer, Element lifecycle, State rebuilds,
binding, and the public widget library. It must remain independent of mpv.

## Public entry points

- `widget.lua` — Widget base classes and type/key reuse rules.
- `element.lua` — mounted Element classes and Widget-to-RenderObject connection.
- `state.lua` — State lifecycle, `set_state`, ticker/controller ownership.
- `build_scope.lua`, `build_owner.lua`, `binding.lua` and `widgets_binding.lua` — BuildScope,
  rebuild queue, inactive/finalize handling and render-tree assembly. `WidgetsBinding` is the
  canonical singleton composition; `WidgetBinding` is the same class alias. Use
  `WidgetsBinding.ensure_initialized():attach(...)` for each additional tree.
- `bind.lua` — Define-time named targets, `Slot`, and `BindRegistry`.
- `provider.lua` — inherited Provider lookup with `of` and `maybe_of` helpers.
- `player_context.lua` — host-independent `PlayerSnapshot`, `PlayerStore`,
  `PlayerScope`, and `PlayerProvider`.
- `key.lua` — `ObjectKey` and `GlobalKey` extensions over the foundation key hierarchy.
- `widgets/` — independent layout, content, input, and button widgets; `basic.lua`
  and `layout.lua` are compatibility aggregates.

Widgets are immutable after construction. Runtime changes use State or explicit
RenderObject setters. Bindings apply before mounting and do not manage a live tree.

The concrete WidgetsBinding is shared within one runtime. Each attached WidgetTree owns its
BuildOwner, root Element, PipelineOwner/RenderOwner scope, dirty state and GlobalKey registry;
disposing one tree does not dispose the shared Binding or other trees.

`PlayerStore` replaces immutable snapshots and exposes disposable subscriptions.
`PlayerScope` owns the subscription and rebuilds a `PlayerProvider` through the normal
State/BuildOwner frame pipeline. `SomeProvider.of(context)` and
`SomeProvider.maybe_of(context)` are listening lookups and are valid from `build()` or
`did_change_dependencies()`. `SomeProvider.read(context)` and
`SomeProvider.maybe_read(context)` are non-listening lookups for initialization and event
callbacks. They do not read `mp` or mutate a mounted Widget.

The Provider API follows the project's minimal `InheritedWidget` model: `of` returns the
Provider Widget, not a `package:provider` value-container result. Lookup uses exact runtime
class identity. `BuildContext` is currently an `Element` alias for implementation
simplicity; callers must treat it as a read-only context handle.

The planned Pages application layer composes Main, the extension 3x3 grid, and `more`.
Extensions enter through Define; config/API hot updates only feed State/Provider or
explicit setters. They do not mutate mounted Widgets or reload extension code.

See [widgets](../dev/design/WIDGETS.md), [host/Define](../dev/design/HOST.md), and
[player application](../dev/design/PLAYER.md).

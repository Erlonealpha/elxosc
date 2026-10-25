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
- `ambient.lua` — `ThemeData`, `Theme`, `DisplaySnapshot`, `DisplayScope` and
  `DefaultTextStyle` application ambients.
- `actions.lua` — the host-independent `HostActions` callback contract and scope.
- `visibility.lua` — `Offstage`, `Visibility`, `AutoHideController` and `AutoHide`.
- `overlay.lua` — the single-owner `Overlay`/`Theatre` runtime and `OverlayEntry` lifecycle.
- `app.lua` — `WidgetsApp`, `DefaultApp`, `Main` and the empty-root `WindowLayer` boundary.
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

`WidgetsApp` supplies the application ambients without requiring `mp`. `DefaultApp` owns one
logical `Theatre` with stable Main, Extension and WindowLayer entries. `Main` uses a configurable
uniform layout scale, a flow-based top/bottom player skeleton and explicitly injected
`HostActions`. `AutoHide` only changes the Main entry; the Extension entry remains mounted and
keeps its State when Main is hidden.

`OverlayEntry` builders execute from a mounted entry context. Visible entries paint in insertion
order; an opaque entry makes lower entries occluded. Occluded or hidden entries remain mounted
through `Offstage` when `maintain_state` is true, otherwise they are removed and disposed on the
next build flush. `OverlayState` publishes a generation-stamped eligibility plan, while the
single Widget/Element/RenderObject owner remains authoritative.

The old nine-region scaffold, fixed grid ids and `more` are not part of the current application
entry. Extensions enter through the initialization Define/Slot path; config/API hot updates only
feed State/Provider or explicit setters. They do not mutate mounted Widgets or reload extension
code.

See [widgets](../dev/design/WIDGETS.md), [host/Define](../dev/design/HOST.md), and
[player application](../dev/design/PLAYER.md).

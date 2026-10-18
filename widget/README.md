# Widget

`widget/` owns the immutable declaration layer, Element lifecycle, State rebuilds,
binding, and the public widget library. It must remain independent of mpv.

## Public entry points

- `widget.lua` — Widget base classes and type/key reuse rules.
- `element.lua` — mounted Element classes and Widget-to-RenderObject connection.
- `state.lua` — State lifecycle, `set_state`, ticker/controller ownership.
- `build_owner.lua` and `binding.lua` — rebuild queue and render-tree assembly.
- `bind.lua` — Define-time named targets, `BindRegistry`, and the static `Slot`
  host.
- `provider.lua` — inherited Provider lookup with `of` and `maybe_of` helpers.
- `player_context.lua` — host-independent `PlayerSnapshot`, `PlayerStore`,
  `PlayerScope`, and `PlayerProvider`.
- `autohide.lua` — host-independent `AutoHide`, its controller, and its
  Provider-aware visibility State.
- `app.lua` — `MpvApp`, `MaterialApp`, `WidgetsApp`, and host-independent
  `DefaultApp` composition.
- `widgets/` — independent layout, content, input, and button widgets; `basic.lua`
  and `layout.lua` are compatibility aggregates.

Widgets are immutable after construction. Runtime changes use State or explicit
RenderObject setters. Bindings apply before mounting and do not manage a live tree.

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

`AutoHide` is a reusable StatefulWidget for `auto`/`always`/`never` visibility. It
reads `PlayerProvider` during build, consumes pointer move/leave events from an
`AutoHideController`, and removes its hidden child from paint and pointer regions.
`player.shell` re-exports the same controller/configuration classes as
`ShellVisibilityController` and `ShellConfig`; it does not implement a second
visibility State.

`Overlay` is the logical, mp-free entry manager. `Theatre` registers stable Main
and Extension entries before dynamic Popup entries; `PopupRoute` is a subclass
of the existing navigation `Route` and pairs optional `ModalBarrier` and content
entries. Plans keep opaque paint occlusion separate from input policy. Lifecycle
adapters receive an entry handle only, so the overlay core does not retain a
`BuildContext` or own a host presenter.

See [widgets](../dev/design/WIDGETS.md), [host/Define](../dev/design/HOST.md), and
[player application](../dev/design/PLAYER.md).

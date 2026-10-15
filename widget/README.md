# Widget

`widget/` owns the immutable declaration layer, Element lifecycle, State rebuilds,
binding, and the public widget library. It must remain independent of mpv.

## Public entry points

- `widget.lua` — Widget base classes and type/key reuse rules.
- `element.lua` — mounted Element classes and Widget-to-RenderObject connection.
- `state.lua` — State lifecycle, `set_state`, ticker/controller ownership.
- `build_owner.lua` and `binding.lua` — rebuild queue and render-tree assembly.
- `bind.lua` — Define-time named targets, `Slot`, and `BindRegistry`.
- `provider.lua` — inherited Provider lookup with `of` and `maybe_of` helpers.
- `player_context.lua` — host-independent `PlayerSnapshot`, `PlayerStore`,
  `PlayerScope`, and `PlayerProvider`.
- `widgets/` — independent layout, content, input, and button widgets; `basic.lua`
  and `layout.lua` are compatibility aggregates.

Widgets are immutable after construction. Runtime changes use State or explicit
RenderObject setters. Bindings apply before mounting and do not manage a live tree.

`PlayerStore` replaces immutable snapshots and exposes disposable subscriptions.
`PlayerScope` owns the subscription and rebuilds a `PlayerProvider` through the normal
State/BuildOwner frame pipeline. Provider consumers use `SomeProvider.of(context)` or
`SomeProvider.maybe_of(context)`; they do not read `mp` or mutate a mounted Widget.

The planned Pages application layer composes Main, the extension 3x3 grid, and `more`.
Extensions enter through Define; config/API hot updates only feed State/Provider or
explicit setters. They do not mutate mounted Widgets or reload extension code.

See [widgets](../dev/design/WIDGETS.md), [host/Define](../dev/design/HOST.md), and
[player application](../dev/design/PLAYER.md).

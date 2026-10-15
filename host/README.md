# Host

`host/` is the only framework directory allowed to import mpv APIs. It adapts the
core contracts to mpv/mpv.net and keeps process, overlay, input, and Define behavior
outside the reusable layers.

## Public entry points

- `mpv_app.lua` — `App`, `MpFrameClock`, `AssPresenter`, and the frame loop.
- `mpv_input.lua` — mouse/keyboard binding and pointer event forwarding.
- `mpv_define.lua` — script-message Define transport and host module facade.
- `mpv_player_context.lua` — mpv property observers bridged to `PlayerStore`.

The app flushes Widget rebuilds, lays out and paints through a backend, then presents
only changed ASS output. Input is routed through `RenderOwner`; host code must not
call widget callbacks directly.

`MpInput` translates mpv mouse bindings into structured `PointerEvent` values with
button, held-button, wheel delta, click-count, source, pointer-id and timestamp
fields. Tree dispatch results are separate from mpv's section claim policy; the
host uses the result's capture field only for pointer capture. Modifier fields
remain absent when the mpv Lua binding does not expose reliable modifier state;
the host does not invent them.

The current input stage includes root-space mouse-area/section management; the next
application stage adds config/API hot updates and multiple named OSD overlay layers.
Overlay z-order is a presentation policy, not Widget or Define priority. Define remains
the sole extension-content ingress.

`App` accepts an optional `player_store` and wraps its root in `PlayerScope`. The
`player` Define module exposes only `get_snapshot()` and `on_update()`; updates do not
re-run Define source. Property observers and Define `mp.on_prop` subscriptions return
disposable handles and must be released on shutdown or extension disposal.

See [host design](../dev/design/HOST.md), [input](../dev/design/INPUT.md),
[player application](../dev/design/PLAYER.md), and [testing](../dev/design/TESTING.md).

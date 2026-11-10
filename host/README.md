# Host

`host/` is the only framework directory allowed to import mpv APIs. It adapts the
core contracts to mpv/mpv.net and keeps process, overlay, input, and Define behavior
outside the reusable layers.

## Public entry points

- `mpv_app.lua` — the single `App` owner and frame loop.
- `mpv_primitives.lua` — `MpFrameClock` and `AssPresenter`, the mpv-backed
  framework adapters owned by `App`.
- `mpv_input.lua` — mouse/keyboard binding and pointer event forwarding.
- `mpv_define.lua` — script-message Define transport, standard package registration,
  explicit default builtins, and host module facades.
- `mpv_player_context.lua` — mpv property observers bridged to `PlayerStore`.
- `ass_measure.lua` — explicitly invoked general ASS `compute_bounds` utility,
  with fixed instance resolution and a reusable hidden overlay. App does not load it.

The app flushes Widget rebuilds, lays out and paints through a backend, then presents
only changed ASS output. Input is routed through `RenderOwner`; host code must not
call widget callbacks directly.

`App` owns exactly one `AssCanvas` and `AssPresenter`. Empty frames are submitted
as empty `ass-events` data to clear the same overlay; shutdown removes that one
overlay idempotently. `MpInput` consumes a cached `RegionSnapshot`, updates existing
section areas without recreating bindings, and clears only sections owned by the
current input instance.

`MpInput` receives a small owner/callback interface rather than an `App` reference.
It translates mpv mouse bindings into structured `PointerEvent` values with
button, held-button, wheel delta, click-count, source, pointer-id and timestamp
fields. Tree dispatch results are separate from mpv's section claim policy; the
host uses the result's capture field only for pointer capture. Modifier fields
remain absent when the mpv Lua binding does not expose reliable modifier state;
the host does not invent them.

The current input stage includes root-space mouse-area/section management; the next
application stage adds config/API hot updates and multiple named OSD overlay layers.
Overlay z-order is a presentation policy, not Widget or Define priority. Define remains
the sole extension-content ingress.

`App` is the sole lifecycle owner for the clock, scheduler, display observers,
input, canvas, presenter and shutdown. It accepts an optional `player_store` and wraps its root in `PlayerScope`. The
`player` Define module exposes `get_snapshot()`/`on_update()` and the explicit
component list in `widget/player/components.lua`, wrapped by `exports.lua`.
`import('player')` copies those names into the extension scope;
`import_as('player')` returns the package without injecting names. Standard packages
are collected by `libs/exports.lua`; adding one does not expand default builtins.
Canonical player controls, themes and context accessors
are shared with framework consumers. Updates do not re-run Define source.
Define contributions are assembled once after seal, before the
WidgetTree is mounted; `WidgetTree` has no bind/assembler responsibility. Property,
event and scope-message subscriptions return idempotent disposable handles and
`MpDefine:shutdown()` releases the host-owned handles.

App teardown preserves the shared Binding and other owner trees. A user State.dispose
error is rethrown after the App releases its render root, clock and presenter.

`AssMeasure({res_x, res_y}):measure(data)` returns the raw host bounds table, `{}`
for an empty image, or `nil, error, kind` (`unavailable`/`error`). Resolution is
floored once at construction. The caller disposes the instance on completion and
on failure; failed removal closes measurement but allows an explicit disposal retry.
The hot path reuses one native command table and does not scan trusted ASS or wrap
results. External input validation and diagnostic conversion live in the offline
[tools](../tools/README.md) adapter. Bounds remain renderer image rectangles in
request coordinates, affected by the actual viewport and font configuration.

See [host design](../dev/design/HOST.md), [input](../dev/design/INPUT.md),
[player application](../dev/design/PLAYER.md), and [testing](../dev/design/TESTING.md).

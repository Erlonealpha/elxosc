# Host

`host/` is the only framework directory allowed to import mpv APIs. It adapts the
core contracts to mpv/mpv.net and keeps process, overlay, input, and Define behavior
outside the reusable layers.

## Public entry points

- `mpv_app.lua` — generic App lifecycle and frame loop; display/text root wrapper,
  explicit root/activity/dispose hooks.
- `mpv_player_app.lua` — PlayerHostApp observer/action/scope/activity assembly.
- `package_catalog.lua`, `builtins.lua` — joins complete owning catalogs and selects the explicit
  default Define construction surface.
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

`App` owns the clock, scheduler, display observers, input, canvas, presenter and
its tree. WidgetsApp supplies display/default text only. PlayerHostApp wraps the
player/theme/action ambients, observes media/capabilities and passes one idempotent
context disposer to App. Root-building, partial mount, observer/input installation
and user teardown failures release acquired resources while preserving the first
error. No player or Define modules are loaded by generic App.

The player package comes from `player/init.lua`; the host adds get_snapshot/on_update.
Framework, player and Define catalogs use static export descriptors. Host registers
all exact package names, including low-level sources and export/module_loader tools,
then adds the mp facade and player runtime functions. Named packages are independent
of collector fields; new registrations do not add builtins automatically.
Define transaction and exact package registration are implemented by `define/src/`.
MpDefine owns its facade subscriptions and main owns the initialization window timer.
`import_as` returns local packages; new packages do not expand default builtins.

Host module types use `elxosc.mod.host.*`; instances/options/facades use
`elxosc.host.*`. `MpPackage` and `PlayerPackage` describe the exact scoped additions.
The development-only [meta entry](../meta/README.md) reuses those types and the
explicit builtin table; host code does not load metadata.

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

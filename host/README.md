# Host

`host/` is the only framework directory allowed to import mpv APIs. It adapts the
core contracts to mpv/mpv.net and keeps process, overlay, input, and Define behavior
outside the reusable layers.

## Public entry points

- `mpv_app.lua` — `App`, `MpFrameClock`, `AssPresenter`, and the frame loop.
- `mpv_input.lua` — mouse/keyboard binding and pointer event forwarding.
- `mpv_define.lua` — script-message Define transport and host module facade.

The app flushes Widget rebuilds, lays out and paints through a backend, then presents
only changed ASS output. Input is routed through `RenderOwner`; host code must not
call widget callbacks directly.

See [host design](../dev/design/HOST.md) and [testing](../dev/design/TESTING.md).

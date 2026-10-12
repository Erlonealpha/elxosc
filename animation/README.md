# Animation

`animation/` owns value interpolation and frame-clock-driven controllers. It has no
mpv dependency and does not emit ASS tags.

## Public entry points

- `curve.lua` — normalized curves such as linear interpolation.
- `tween.lua` — interpolation for numbers, `Offset`, `Size`, `Color`, and custom
  lerpers.
- `controller.lua` — `AnimationController`, repeat/reverse/stop behavior, and
  listener lifecycle.

Controllers use `scheduler.Scheduler`/`Ticker`. A listener updates a target value;
the target RenderObject or State decides whether that update is paint-only or needs
layout. Dispose controllers owned by State during unmount.

See [rendering and animation](../dev/design/RENDERING.md) for the dirty contract.

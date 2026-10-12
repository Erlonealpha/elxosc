# Foundation

`foundation/` contains host-independent value types shared by every framework layer.
It must remain usable without mpv.

## Public entry points

- `geometry.lua` — `Offset`, `Point`, `Size`, `Rect`, and `EdgeInsets`.
- `color.lua` — immutable-by-convention RGBA `Color` values.
- `anchor.lua` — nine paint anchors and box fractions.
- `transform.lua` — finite 2D matrix composition, point/rect mapping, and inverse.
- `pointer_event.lua` — normalized pointer event values.

Value helpers return new objects and do not mutate caller-owned geometry. This layer
does not know about layout, ASS, widgets, or `mp`.

See [architecture](../dev/design/ARCHITECTURE.md) for dependency ownership.

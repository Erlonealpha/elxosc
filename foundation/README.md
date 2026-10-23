# Foundation

`foundation/` contains host-independent value types shared by every framework layer.
It must remain usable without mpv.

## Public entry points

- `geometry.lua` — `Offset`, `Point`, `Size`, `Rect`, and `EdgeInsets`.
- `color.lua` — immutable-by-convention RGBA `Color` values.
- `anchor.lua` — nine paint anchors and box fractions.
- `transform.lua` — finite 2D matrix composition, point/rect mapping, and inverse.
- `pointer_event.lua` — validated mouse event values. It accepts the historical
  `(type, point, data, extra)` constructor as well as a fields table, copies
  points and modifier/button snapshots, and retains arbitrary extension fields.
  The supported event types are `down`, `up`, `move`, `cancel`, `enter`,
  `leave`, `wheel`, and `double`.
- `key_event.lua` — validated structured keyboard event values. They
  contain a non-empty key, `down`/`up`/`press` type, copied modifier snapshot,
  finite timestamp when supplied, and an `is_repeat` flag defaulting to `false`.
  Focus routing is owned by a later host/application layer.
- `key.lua` — host-independent `Key`, `LocalKey`, `ValueKey` and `UniqueKey` identity
  primitives used by Widget reconciliation.
- `binding_base.lua` — instance-scoped binding lifecycle base; it does not create a global
  framework singleton.

Value helpers return new objects and do not mutate caller-owned geometry. This layer
does not know about layout, ASS, widgets, focus, routing, or `mp`. Pointer events
also expose `legacy_data()`: an explicit non-`nil` payload wins, buttons are used
for button events, and wheel deltas retain the historical scalar vertical form
when no horizontal movement is present.

See [architecture](../dev/design/ARCHITECTURE.md) for dependency ownership.

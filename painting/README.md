# Painting

`painting/` defines backend-neutral drawing contracts and paint value objects. It
must remain independent of mpv and concrete ASS output.

## Public entry points

- `canvas.lua` — `Canvas` state, transform, clip, primitive, text, and image contract.
- `paint.lua` — fill/stroke style, stroke width, cap, join, and color.
- `path.lua` — path verbs and primitive lowering.
- `text_paint.lua` — explicit text anchor and visual offset.

Coordinates are logical pixels. `TextPaint.offset` affects visual painting only;
layout and hit testing remain RenderObject responsibilities. Concrete backends belong
in `backends/`.

`PaintingContext` belongs to `render/`, not this contract layer. It owns the current Canvas
for a paint pass and forwards backend-neutral operations without exposing ASS details.

See [rendering](../dev/design/RENDERING.md).

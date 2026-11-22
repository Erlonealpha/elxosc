# Painting

`lib/src/painting/` defines backend-neutral drawing contracts and paint value objects. It
must remain independent of mpv and concrete ASS output.

Source modules load as `src.painting.*`; the host-independent collector is
[`lib/painting.lua](../../painting.lua), available through `require 'painting'`.

## Public entry points

- `canvas.lua` — `Canvas` state, transform, clip, primitive, text, and image contract.
- `paint.lua` — fill/stroke style, stroke width, cap, join, and color.
  Paint is an independent dataclass with direct mutable fields and shared methods;
  `copy()` returns a new Paint while retaining the supplied Color reference.
  Default Color construction stays per instance. Type guards/subclasses use dataclass.
- `path.lua` — path verbs and primitive lowering.
- `text_paint.lua` — explicit text anchor and visual offset.
  TextPaint is an independent dataclass retaining exact-class resolution,
  validated finite Offset, explicit-anchor intent and fresh `copy_with` results.

Coordinates are logical pixels. `TextPaint.offset` affects visual painting only;
layout and hit testing remain RenderObject responsibilities. Concrete backends belong
in `backends/`.

`PaintingContext` belongs to `render/`, not this contract layer. It owns the current Canvas
for a paint pass and forwards backend-neutral operations without exposing ASS details.
`PaintingBinding` is a role facade over the shared concrete WidgetsBinding; Canvas resources
remain owned by the attached host/tree scope.

See [rendering](../../../dev/design/RENDERING.md).

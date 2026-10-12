# Render

`render/` owns the mutable, persistent RenderObject tree. It is host-free and does
not import Widget modules or mpv.

## Public entry points

- `render_object.lua` — child ownership, layout/paint, hit testing, pointer paths,
  parent data, and dirty propagation.
- `render_owner.lua` — root viewport, frame work, pointer dispatch, hover, and capture.
- Layout boxes — padding, align, flex, stack, sized/constrained/overflow/fitted boxes.
- Visual boxes — decorated/custom paint/text, offset, `TransformBox`, and
  `LayoutScaleBox`.
- `gesture.lua` — pointer-to-gesture behavior used by Widget controls.

RenderObject layout must return finite sizes within Constraints. Paint-only setters
must not request layout; layout-affecting setters must request both. Transform boxes
accept only finite positive axis-aligned scales and map input through the inverse.

See [rendering](../dev/design/RENDERING.md) and [architecture](../dev/design/ARCHITECTURE.md).

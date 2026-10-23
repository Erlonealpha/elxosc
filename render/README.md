# Render

`render/` owns the mutable, persistent RenderObject tree. It is host-free and does
not import Widget modules or mpv.

## Public entry points

- `render_object.lua` — child ownership, layout/paint, hit testing, pointer paths,
  root-space pointer regions, parent data, and dirty propagation.
- `render_owner.lua` — compatibility implementation for the single-root owner.
- `pipeline_owner.lua` — canonical `PipelineOwner` name; exports the same class as
  `RenderOwner`.
- `painting_context.lua` — Canvas/child paint/clip boundary without a Layer tree.
- `renderer_binding.lua` — instance-scoped PipelineOwner/Canvas binding facade.
- Layout boxes — padding, align, flex, stack, sized/constrained/overflow/fitted boxes.
- Visual boxes — decorated/custom paint/text, offset, `TransformBox`, and
  `LayoutScaleBox`.
- `gesture.lua` — pointer-to-gesture behavior used by Widget controls.

RenderObject layout must return finite sizes within Constraints. Paint-only setters
must not request layout; layout-affecting setters must request both. Transform boxes
accept only finite positive axis-aligned scales and map input through the inverse.

`RenderOwner:pointer_regions()` returns non-empty, root-space rectangles for nodes
that claim down/up or wheel input. Child mappings are composed through offsets and
supported paint/layout transforms, then clipped by every ancestor's rectangular
hit bounds. `RenderOwner:has_pointer_capture()` reports whether the captured node
is still mounted; it cancels a detached capture before returning false, and the
cancelled sequence's stale up/cancel is not retargeted to the replacement tree.
Capture keeps the original target while additional button sequences are active;
the target is released only after the final captured button is released or the
sequence is cancelled.

`RenderOwner:dispatch_pointer_result()` returns a structured result with separate
`handled`, `capture`, and `stop_propagation` fields. `dispatch_pointer()` remains
the boolean compatibility wrapper. Render objects may implement
`on_pointer_event(event, local_point)` to inspect structured root-space events;
the default adapter preserves existing `on_pointer(event, local_point, data)`
implementations.

See [rendering](../dev/design/RENDERING.md) and [architecture](../dev/design/ARCHITECTURE.md).

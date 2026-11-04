# Render

`render/` owns the mutable, persistent RenderObject tree. It is host-free and does
not import Widget modules or mpv.

## Public entry points

- `render_object.lua` — child ownership, layout/paint, hit testing, pointer paths,
  root-space pointer regions, parent data, and dirty propagation.
- `render_owner.lua` — compatibility implementation for the single-root owner.
- `region_snapshot.lua` — immutable copies of one root's effective pointer regions;
  `RenderOwner:region_snapshot()` caches one snapshot per input generation.
- `pipeline_owner.lua` — canonical `PipelineOwner` name; exports the same class as
  `RenderOwner`.
- `painting_context.lua` — Canvas/child paint/clip boundary without a Layer tree.
  All built-in child traversal uses `paint_child`/`paint_children`; `with_save` and
  `clip_rect_and_paint` restore Canvas state on failure as well as success; `with_opacity`
  applies a backend-neutral paint-only subtree alpha scope.
- `renderer_binding.lua` — RendererBinding role facade; it resolves to the shared WidgetsBinding
  composition and creates per-tree PipelineOwner copies.
- Layout boxes — padding, align, flex, stack/positioned, sized/constrained/overflow/fitted boxes.
- Visual boxes — decorated/custom paint/text, offset, `TransformBox`, and
  `LayoutScaleBox`.
- `RenderDecoratedBox` accepts backend-neutral border, blur and shadow intent;
  the ASS backend lowers it to static tags.
- `progress_bar.lua` — fixed-layout progress/buffer/handle painting with explicit
  seek capture; progress values are paint-only while bar height is layout-affecting.
- `offstage.lua` — lifecycle-preserving layout boundary that suppresses paint,
  hit testing and pointer regions while hidden.
- `opacity.lua` — paint-only subtree alpha; layout, hit testing and pointer regions remain
  unchanged until a visibility owner explicitly sets `hidden`.
- `RenderText:set_glow_override()` paints a second blurred glyph at the same position;
  it is paint-only and does not change text measurement or input geometry.
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

`RegionSnapshot` is invalidated by layout/tree changes and explicit paint-only
input changes. Host code receives copied region values and cannot mutate the
owner's cache. Snapshot invalidation never synthesizes a hover event.

`RenderStack` accepts `Positioned` parent data (`left`/`top`/`right`/`bottom` plus optional
`width`/`height`). The parent computes child constraints and offsets; paint, hit testing and
root-space pointer regions use the same offset. It is a finite root-relative layout contract,
not an ASS coordinate escape hatch.

The current renderer has no public `RepaintBoundary` or `RelayoutBoundary`. Paint dirty and
layout dirty propagate to the root, `PaintingContext` has no Layer/cache contract, and the
single ASS presenter caches only the complete payload. Boundary optimization is deferred until
benchmark evidence, cache/order semantics, finite-constraint behavior, and pointer-region
regressions are specified. A paint-only animation that changes transform, offset, alignment or
input eligibility must still invalidate the input snapshot explicitly.

`RenderOwner:dispatch_pointer_result()` returns a structured result with separate
`handled`, `capture`, and `stop_propagation` fields. `dispatch_pointer()` remains
the boolean compatibility wrapper. Render objects may implement
`on_pointer_event(event, local_point)` to inspect structured root-space events;
the default adapter preserves existing `on_pointer(event, local_point, data)`
implementations.

See [rendering](../dev/design/RENDERING.md) and [architecture](../dev/design/ARCHITECTURE.md).

Owner naming migration and alias removal conditions are recorded in
[widget migration aliases](../widget/README.md#migration-aliases).

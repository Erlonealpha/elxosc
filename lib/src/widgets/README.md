# Basic widgets and runtime

`require 'widgets'` collects members from the flat `src.widgets.*` modules.
`require 'src.widgets'` is a one-way alias for that collector. Sources import
other sources directly; they do not load collectors, Material, player or Define.

- `framework.lua`, `element.lua`, `state.lua` own immutable descriptions,
  reconciliation and lifecycle. Each class has one defining source.
- `binding.lua`, `widgets_binding.lua`, `build_owner.lua`, `build_scope.lua`
  connect the shared Binding composition to independently owned trees.
  BuildOwner invalidates registered traversal caches immediately on mount,
  unmount, active-state or child-order changes. Owners hold cache containers
  weakly; consumers query live State capabilities rather than caching decisions.
- Layout wrappers, Text, CustomPaint, Icon, GestureDetector, Provider, Visibility,
  Overlay and Navigator are basic widgets. Display/DefaultTextStyle belong to
  `ambient.lua`; design Theme belongs to Material.
- `ambient.TextLayoutScope({layout, generation, child})` supplies tree-local text
  measurement. Text prefers its explicit text_layout, then the nearest scope, then
  the offline module default. Replacing layout/generation reuses RenderText and
  invalidates its layout; Tooltip drops its paragraph on the same change.
- HoverText uses GestureDetector and RenderText setters. Hover/press/leave change
  foreground/glow without rebuilding, measuring text or invalidating layout.
  Align preserves the allocated position while the gesture surrounds content and
  optional min_width; overwide text clips to its box, leaving allocated blanks passive.
- Tooltip owns hover, measurement, anchoring and preview hooks. PlayerTooltip
  supplies player styling and AutoHide eligibility from above this layer.
  Real hit-path movement restores suppressed hover and updates previews during
  child capture; policy changes alone do not synthesize hover or rebuild layout.
  Text changes enqueue one stable callback on RenderOwner; layout/flush_prepare
  prepares the final label before paint. Fixed label motion does not measure.
  Dispose cancels queued work. width_for_text may reserve a stable visual width
  without changing the displayed paragraph; it must return a finite non-negative value.
  Finite bounds_width minus margins supplies the preparation width, so an explicit
  wrapping/ellipsis style is resolved before paint. Changing these bounds renews
  the prepared paragraph; default Tooltip styles remain unwrapped.
- Text passes TextStyle.max_lines/overflow to layout. Clip/ellipsis crop a naturally
  overflowing constrained box; Text.clip remains the explicit width-only option.
- Icon owns nominal glyph layout and paint offsets. Its bundled font default is
  supplied by the resource contract in `fonts.material_symbols`; custom font
  families do not acquire Material Symbols variation intent.

`WidgetBinding` is the existing identity alias for `WidgetsBinding`; `RenderOwner`
and `PipelineOwner` likewise remain the same class. These class aliases are not
old module-path fallbacks. The old widget/widget.widgets/basic/layout collectors
have been removed; use widgets, material or the owning source.

See [widgets](../../../dev/design/WIDGETS.md),
[architecture](../../../dev/design/ARCHITECTURE.md) and
[Material](../material/README.md).

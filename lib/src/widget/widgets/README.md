# Built-in widgets

This directory contains the public Widget wrappers around `render/` nodes.

## Groups

- Layout: `padding`, `align`, `sized_box`, `container`, `flex`, `stack`, `positioned`,
  `constraints`, `overflow`, `offset_box`, `transform_box`.
- Content: `text`, `icon`, `custom_paint`. `Icon` uses the bundled Material Symbols
  Rounded family and carries typed FILL/WGHT/GRAD/opsz variation intent without
  exposing backend-specific override strings.
- Input and controls: `gesture_detector`, `button_base`, `button_style`, `button`,
  `elevated_button`, `outlined_button`, `text_button`, `icon_button`, `tooltip`,
  `progress_indicator`, `slider`, `hover_text`.
- Compatibility aggregates: `basic.lua` and `layout.lua`.

Each public widget owns an Options contract, leaves caller tables unchanged, and
updates only its associated RenderObject. New widgets should be added as an
independent module first, then explicitly exported by any compatibility aggregate.

`Tooltip` wraps a child without taking its clicks. Labels paint in the existing
tree and do not affect layout; pointer motion reuses the paragraph and input
snapshot. It centers on the laid-out child by default. Explicit `anchor_*` and
`bounds_*` describe a shared logical coordinate space; `margin` clamps/crops wide
labels and a top-edge collision flips the label below the anchor. It does not
create an overlay entry, so the caller chooses paint order and ancestor clipping.
`on_hover_point`/`on_hover_leave` and `paint_for_point` support external previews;
AutoHide policy changes and disposal clear hover resources.

`Slider` selects a controlled `value` between finite `min <= max`, continuously or
with positive integer `divisions`. `on_changed(value)`, `on_change_start(old_value)`
and `on_change_end(final_value)` are separate callbacks. Missing `on_changed` or
equal bounds disables selection. Cancellation completes the interaction through
`on_change_end`, matching Flutter. Rebuilding with a new value updates the same
RenderSlider and only dirties paint. `secondary_track_value` uses the same numeric
range. Track padding, thumb/overlay radii and active/inactive/disabled colors are
visual options. Unbounded layout falls back to a 144-unit track with padding.
The implemented pointer interaction is tap-and-slide; wheel policy belongs to
an outer GestureDetector.

`LinearProgressIndicator` reports read-only progress. Finite `value` is clamped to
0..1; nil creates an indeterminate frame-clock animation. The indeterminate mode
requires a Scheduler, owns one ticker, updates paint without rebuild/layout and
stops the ticker in determinate mode and on disposal. It has no thumb, seek,
chapter or pointer API. `min_height` and `border_radius` control its track.

`HoverText` composes Text and ButtonBase with transparent backgrounds, foreground
and glow feedback, and `on_tap`. It remains plain text without a callback. These
four components are exported by both `widget.widgets.basic` and `widget` and
require neither PlayerProvider nor HostActions.

Slider and LinearProgressIndicator follow Flutter's behavioral separation, not
its full Material, focus, accessibility or shape-theme APIs. Media Timeline is
owned by `widget/player/timeline.lua`; the mixed ProgressBar/SeekBar API is removed.

Player state is not a Widget option. Use `PlayerProvider.of(context)` or
`PlayerProvider.maybe_of(context)` from a build method and let `PlayerScope` deliver
new snapshots through the existing rebuild pipeline.

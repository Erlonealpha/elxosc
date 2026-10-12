# Built-in widgets

This directory contains the public Widget wrappers around `render/` nodes.

## Groups

- Layout: `padding`, `align`, `sized_box`, `container`, `flex`, `stack`,
  `constraints`, `overflow`, `offset_box`, `transform_box`.
- Content: `text`, `icon`, `custom_paint`.
- Input and controls: `gesture_detector`, `button_base`, `button_style`, `button`,
  `elevated_button`, `outlined_button`, `text_button`, `icon_button`.
- Compatibility aggregates: `basic.lua` and `layout.lua`.

Each public widget owns an Options contract, leaves caller tables unchanged, and
updates only its associated RenderObject. New widgets should be added as an
independent module first, then explicitly exported by any compatibility aggregate.

`mpv/` is reserved for host-specific widget experiments; it is not part of the
host-free widget contract yet.

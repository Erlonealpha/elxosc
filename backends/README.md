# Backends

`backends/` implements framework contracts without importing `mp`. The host selects
one backend at assembly time.

## Public entry points

- `ass_canvas.lua` — converts Canvas calls into static ASS `ass-events` lines,
  including transforms, clipping, text anchors, colors, and finite positive scale.
- `ass_text_layout.lua` — deterministic estimated text measurement for ASS.
- `record.lua` — records drawing calls for unit tests and backend-independent checks.

ASS output is a presentation format, not a layout input. Do not make RenderObject
code parse ASS strings or add PTS-based `\move`/`\t` animation tags here.

See [rendering](../dev/design/RENDERING.md) and [host](../dev/design/HOST.md).

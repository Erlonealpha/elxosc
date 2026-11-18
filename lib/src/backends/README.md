# Backends

`lib/src/backends/` implements framework contracts without importing `mp`. The host selects
one backend at assembly time.

Source modules load as `src.backends.*`; the host-independent collector is
[`lib/backends.lua](../../backends.lua), available through `require 'backends'`.

## Public entry points

- `ass_canvas.lua` — converts Canvas calls into static ASS `ass-events` lines,
  including transforms, clipping, text anchors, colors, opacity, blur, outline/shadow intent,
  and finite positive scale.
- `ass_text_layout.lua` — injected native line spans, bounded LRU and offline estimates.
- `ass_text.lua` — shared font/shape and literal-text encoding for drawing and measurement.
- `record.lua` — records drawing calls for unit tests and backend-independent checks.

ASS output is a presentation format, not a layout input. Do not make RenderObject
code parse ASS strings or add PTS-based `\move`/`\t` animation tags here.

`AssCanvas` emits one ASS event per shape or non-empty paragraph row; raw newline
and NUL injection is rejected so mpv's internal Layer/ReadOrder mapping remains
host-owned. `AssPresenter` is the single cache/submit owner for the App and
deduplicates only after a successful update. Opacity scopes multiply each emitted
shape/text alpha and are restored with Canvas save/restore.
Multiline text uses static row events rather than native `\N` spacing. Each row's
middle anchor advances by `Paragraph.line_height`, preserving the paragraph's
horizontal anchor, visual offset and canvas scale. Blank rows advance without
events. Single-row positioning and explicit nine-anchor behavior remain intact.

See [rendering](../../../dev/design/RENDERING.md) and [host](../../../dev/design/HOST.md).

`AssTextLayout({measure_ass, res_x, res_y, default_font_family})` owns no host resources.
`measure_line(text, style)` returns width, `native`/`estimate`/`empty`, and an optional
reason. Native spans use normalized left/right positioning differences with a 2px
consistency guard and viewport bounds checks. They are not font advance or ink metrics.
Empty text and font size zero avoid native calls; pure space/NBSP uses an exact-count
marker difference. Unsupported whitespace and clipped/unreliable results use estimates.

The default LRU limits are 512 entries and 262144 original-text/key bytes; options
`cache_entries`/`cache_bytes` can reduce these or disable caching. Keys use shape values,
excluding paint effects and paragraph constraints. `cache_stats()` returns a copy.
Native errors latch for this layout; the owning host replaces it to recover.

# Text

`text/` describes backend-neutral text intent and layout results. It must not import
mpv or emit ASS tags.

## Public entry points

- `text_style.lua` — `TextStyle` and the closed `left`/`center`/`right` alignment set.
- `paragraph.lua` — immutable layout result: text, lines, natural size, and line height.
- `text_layout.lua` — measurement/layout contract with shared wrapping behavior.

`Paragraph.size` is natural content size; `RenderText.size` is the constrained layout
box. ASS measurement is an estimate supplied by `backends/ass_text_layout.lua`, so
ink bounds and baseline precision are not silently promised.

See [rendering](../dev/design/RENDERING.md).

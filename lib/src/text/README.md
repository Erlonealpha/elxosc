# Text

`lib/src/text/` describes backend-neutral text intent and layout results. It must not import
mpv or emit ASS tags.

Source modules load as `src.text.*`; the host-independent collector is
[`lib/text.lua](../../text.lua), available through `require 'text'`.

## Public entry points

- `text_style.lua` — `TextStyle` and the closed `left`/`center`/`right` alignment set.
- `paragraph.lua` — immutable layout result: text, lines, natural size, and line height.
- `text_layout.lua` — measurement/layout contract with shared wrapping behavior.

`Paragraph.size` is natural content size; `RenderText.size` is the constrained layout
box. ASS measurement uses an injected host positioning span with an explicit offline
estimate fallback. Neither result promises ink bounds or baseline precision. The module
default carries no host resources; Widget consumers prefer the nearest TextLayoutScope.

See [rendering](../../../dev/design/RENDERING.md).

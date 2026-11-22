# Text

`lib/src/text/` describes backend-neutral text intent and layout results. It must not import
mpv or emit ASS tags.

Source modules load as `src.text.*`; the host-independent collector is
[`lib/text.lua](../../text.lua), available through `require 'text'`.

## Public entry points

- `text_style.lua` — `TextStyle`, `left`/`center`/`right` alignment, optional positive
  `max_lines`, and `visible`/`clip`/`ellipsis` overflow. `copy_with` preserves fields
  passed as nil; construct a fresh style to clear an optional line limit.
- `paragraph.lua` — original text, visible lines, natural size, uniform line advance,
  and per-line width/provenance/one-based half-open UTF-8 byte ranges. Hard breaks
  and a synthetic ellipsis consume no source bytes. Arrays and records are copied;
  `with_style` preserves prepared results for paint effects. Manually constructed
  legacy paragraphs may omit line metrics.
  Paragraph uses independent dataclass storage/shared methods. Its custom
  constructor and `with_style` still copy lines and metric records; shallow
  dataclass export/replace is not a substitute for these protection boundaries.
- `text_layout.lua` — whole-line measurement and shared finite wrapping. CR/LF/CRLF
  retain empty rows; a tab becomes four spaces with its original byte range.
  Other spaces remain intact. Empty source has no rows. A line limit measures at
  most one extra row to detect truncation, while validating all original UTF-8.
- `grapheme.lua` — `clusters`, `validate_utf8`, and finite `is_cjk` break support.
  Keeps selected combining marks, variation selectors, emoji modifiers/ZWJ/tag
  sequences, regional-indicator pairs and Hangul combinations together. These are
  finite rules rather than complete UAX 14/29, bidi editing or Indic segmentation.

Wrapping prefers word/CJK boundaries, then splits an overlong unit at supported
clusters. A single overwide cluster remains visible unless overflow clips or
ellipsizes it. NBSP is not an ordinary word break; overlong units can still split.
Ellipsis measures each supported prefix plus U+2026 as a whole shaped candidate,
retains the longest measured fitting prefix, and emits an empty row if even U+2026
does not fit. Widths are never computed by adding isolated glyph measurements.

`Paragraph.size` is natural content size; `RenderText.size` is the constrained layout
box. ASS measurement uses an injected host positioning span with an explicit offline
estimate fallback. Neither result promises ink bounds or baseline precision. The module
default carries no host resources; Widget consumers prefer the nearest TextLayoutScope.
ASS draws each non-empty row separately at the logical line advance; blank rows
still advance. Clip/ellipsis crop an overflowing constrained RenderText box.

See [rendering](../../../dev/design/RENDERING.md).

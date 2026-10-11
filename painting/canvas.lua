-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The drawing contract every render backend implements.
--
-- This is the single seam that keeps elxosc's render layer abstract: widget,
-- element and render-tree code only ever call these methods, so the concrete
-- output (ASS `osd-overlay` today, a mpv.net surface tomorrow, an offline
-- recorder for tests) is chosen by swapping a Canvas subclass.
--
-- Coordinates are in logical pixels; `save`/`restore` are expected to
-- preserve the current transform and clip stack. Backends may implement fewer
-- methods than the full list as long as the ones the framework uses are
-- covered -- the defaults raise `NotImplementedError` to make that explicit
-- instead of silently drawing nothing.

local std = require 'elxlibs.std'

local raise = std.raise

-- Every method below declares the backend contract; the base implementation
-- intentionally ignores its parameters (it just raises).
---@diagnostic disable: unused

local M = {}

--- An opaque, backend provided image handle (Flutter's `ui.Image`).
---@class Image

---@param method string
local function abstract(method)
    raise(std.NotImplementedError(
        string.format('Canvas:%s must be implemented by a rendering backend', method)))
end

---@class Canvas : std.object
---@overload fun(): Canvas
local Canvas = std.class.new('Canvas')

--== state ================================================================

--- Push the current transform/clip state onto the backend's stack.
function Canvas:save()
    abstract('save')
end

--- Pop the state pushed by the matching `save`.
function Canvas:restore()
    abstract('restore')
end

---@param dx number
---@param dy number
function Canvas:translate(dx, dy)
    abstract('translate')
end

---@param sx number
---@param sy number? defaults to `sx`
function Canvas:scale(sx, sy)
    abstract('scale')
end

---@param rect Rect
function Canvas:clip_rect(rect)
    abstract('clip_rect')
end

--== primitives ===========================================================

---@param rect Rect
---@param paint Paint
function Canvas:draw_rect(rect, paint)
    abstract('draw_rect')
end

---@param rect Rect
---@param radius number
---@param paint Paint
function Canvas:draw_rrect(rect, radius, paint)
    abstract('draw_rrect')
end

---@param path Path
---@param paint Paint
function Canvas:draw_path(path, paint)
    abstract('draw_path')
end

---@param from Offset
---@param to Offset
---@param paint Paint
function Canvas:draw_line(from, to, paint)
    abstract('draw_line')
end

--== content ==============================================================

--- Draw a laid out text run. `paragraph` is produced by the text layer, not
--- by the canvas, so backends never deal with raw strings here.
--- The backend places the chosen content reference at `position + offset`,
--- then applies the Canvas transform. This is not an exact glyph ink origin.
---@param paragraph Paragraph
---@param position Offset logical target point for the paint anchor
---@param text_paint TextPaint? defaults to top-left with zero offset
function Canvas:draw_text(paragraph, position, text_paint)
    abstract('draw_text')
end

---@param image Image?
---@param rect Rect destination rectangle
function Canvas:draw_image(image, rect)
    abstract('draw_image')
end

M.Canvas = Canvas

return M

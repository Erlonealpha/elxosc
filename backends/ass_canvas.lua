-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- ASS `Canvas` backend.
--
-- Turns drawing calls into ASS override text, one line per event, exactly the
-- shape `osd-overlay`'s `ass-events` wants (each line becomes the `Text` of a
-- `Dialogue` event, so no `Dialogue:` prefix and no script header).
--
-- Conventions follow uosc's `lib/ass.lua` (the battle tested reference for
-- ASS UIs), themselves verified against mpv's `sub/osd_libass.c` /
-- `player/lua/assdraw.lua`:
--   * events   -> `\pos(0,0)\rDefault\an7\blur0`, then *absolute* coordinates
--                 (libass does not re-anchor drawings to their bounding box)
--   * drawing  -> `\p<n>` in its own block, coordinates scaled by 2^(n-1)
--   * colour   -> `\1c&HBBGGRR&` (note the BGR order)
--   * alpha    -> `\1a&HAA&` with AA = 255 - opacity (00 = opaque)
--   * reset    -> `\rDefault` neutralises the `OSD` style mpv applies
-- mpv assigns Layer=0 and monotonically increasing ReadOrder to these lines.
-- Keep each call in one event; neither field is a public Canvas parameter.

local std = require 'elxlibs.std'
local canvas = require 'painting.canvas'
local path_mod = require 'painting.path'
local color_mod = require 'foundation.color'
local paint_mod = require 'painting.paint'
local anchor_mod = require 'foundation.anchor'
local text_paint_mod = require 'painting.text_paint'
local text_style = require 'text.text_style'
local transform_mod = require 'foundation.transform'

local Canvas = canvas.Canvas
local Path = path_mod.Path
local Verb = path_mod.Verb
local Color = color_mod.Color
local Paint = paint_mod.Paint
local Anchor = anchor_mod.Anchor
local Align = text_style.Align
local Matrix2D = transform_mod.Matrix2D
local raise = std.raise
local math = math
local floor = math.floor
local min = math.min
local max = math.max
local sqrt = math.sqrt
local format = string.format
local concat = table.concat
local ipairs = ipairs

local ASS_ANCHORS = {
    [Anchor.TOP_LEFT] = 7,
    [Anchor.TOP_CENTER] = 8,
    [Anchor.TOP_RIGHT] = 9,
    [Anchor.CENTER_LEFT] = 4,
    [Anchor.CENTER] = 5,
    [Anchor.CENTER_RIGHT] = 6,
    [Anchor.BOTTOM_LEFT] = 1,
    [Anchor.BOTTOM_CENTER] = 2,
    [Anchor.BOTTOM_RIGHT] = 3,
}

local ASS_TEXT_ALIGN_ANCHORS = {
    [Align.LEFT] = 4,
    [Align.CENTER] = 5,
    [Align.RIGHT] = 6,
}

local M = {}

---@param channel number 0..1
---@return number 0..255
local function to_byte(channel)
    return floor(channel * 255 + 0.5)
end

--- ASS `&HBBGGRR&` digits for a colour.
---@param color_ Color
---@return string
function M.ass_rgb(color_)
    return format('%02X%02X%02X', to_byte(color_.b), to_byte(color_.g), to_byte(color_.r))
end

--- ASS `&HAA&` digits for a colour's alpha (00 = opaque, FF = transparent).
---@param color_ Color
---@return string
function M.ass_alpha(color_)
    return format('%02X', 255 - to_byte(color_.a))
end

---@param value number
---@return string
local function ris(value)
    return format('%d', floor(value + 0.5))
end

---@param value number
---@return int
local function ri(value)
    return floor(value + 0.5)
end

---@param paint Paint
---@param force_fill boolean?
---@return string
local function paint_tags(paint, force_fill)
    local rgb = M.ass_rgb(paint.color)
    local alpha = M.ass_alpha(paint.color)
    if paint.style == 'stroke' and not force_fill then
        return format('\\bord%g\\shad0\\3c&H%s&\\3a&H%s&\\1c&H%s&\\1a&HFF',
            paint.stroke_width, rgb, alpha, rgb)
    end
    return format('\\bord0\\shad0\\1c&H%s&\\1a&H%s&', rgb, alpha)
end

--- Escape literal text so it cannot open an ASS override block. Mirrors what
--- mpv's own OSD does: prefix `{` with `\`, and break `\` with a word joiner.
---@param text string
---@return string
local function escape_text(text)
    text = text:gsub('\\', '\\\226\128\128')
    text = text:gsub('{', '\\{')
    return text
end

---@class AssCanvas : Canvas
---@field events string[] one ASS `Text` line per drawing call
---@field subpixel integer `\p` level (4 = 8x sub-pixel, the assdraw default)
---@overload fun(subpixel: integer?): self
local AssCanvas = std.class.new('AssCanvas', { Canvas })

function AssCanvas:__init(subpixel)
    self.events = {}
    self.subpixel = subpixel or 4
    self._stack = {}
    self._matrix = Matrix2D.identity()
    self._clip = nil
end

--- Drop everything produced so far (start of a frame).
function AssCanvas:reset()
    self.events = {}
    self._stack = {}
    self._matrix = Matrix2D.identity()
    self._clip = nil
end

---@return string the `ass-events` payload (one line per event)
function AssCanvas:text()
    return concat(self.events, '\n')
end

---@param text string
function AssCanvas:_push(text)
    if type(text) ~= 'string' or text == '' or text:find('[\r\n%z]') then
        raise(std.ValueError('ASS events must be single non-empty lines without NUL'))
    end
    self.events[#self.events + 1] = text
end

---@param x number
---@param y number
---@return number
---@return number
function AssCanvas:_apply(x, y)
    local matrix = self._matrix
    return matrix.a * x + matrix.c * y + matrix.tx,
        matrix.b * x + matrix.d * y + matrix.ty
end

--== state ================================================================

function AssCanvas:save()
    local stack = self._stack
    stack[#stack + 1] = { self._matrix, self._clip }
end

function AssCanvas:restore()
    local frame = table.remove(self._stack)
    if frame then
        self._matrix, self._clip = frame[1], frame[2]
    end
end

---@param name string
---@param value any
---@return number
local function check_finite(name, value)
    if type(value) ~= 'number' or value ~= value
        or value == math.huge or value == -math.huge then
        raise(std.ValueError('AssCanvas.' .. name .. ' must be a finite number'))
    end
    return value
end

function AssCanvas:translate(dx, dy)
    dx, dy = check_finite('translate.x', dx), check_finite('translate.y', dy)
    self._matrix = self._matrix:multiply(Matrix2D.translation(dx, dy))
end

function AssCanvas:scale(sx, sy)
    sy = sy == nil and sx or sy
    sx, sy = check_finite('scale.x', sx), check_finite('scale.y', sy)
    if sx <= 0 or sy <= 0 then
        raise(std.ValueError('AssCanvas only supports positive axis scales'))
    end
    self._matrix = self._matrix:multiply(Matrix2D.scale(sx, sy))
end

function AssCanvas:clip_rect(rect)
    local x0, y0 = self:_apply(rect.left, rect.top)
    local x1, y1 = self:_apply(rect.right, rect.bottom)
    local next_clip = {
        left = min(x0, x1),
        top = min(y0, y1),
        right = max(x0, x1),
        bottom = max(y0, y1),
    }
    local previous = self._clip
    if previous then
        next_clip.left = max(next_clip.left, previous.left)
        next_clip.top = max(next_clip.top, previous.top)
        next_clip.right = min(next_clip.right, previous.right)
        next_clip.bottom = min(next_clip.bottom, previous.bottom)
    end
    self._clip = next_clip
end

---@return string
function AssCanvas:_clip_tag()
    local clip = self._clip
    if not clip then
        return ''
    end
    return format('\\clip(%s,%s,%s,%s)',
        ris(clip.left), ris(clip.top), ris(clip.right), ris(clip.bottom))
end

--== primitives ===========================================================

---@param path Path
---@param paint Paint?
---@param force_fill boolean?
function AssCanvas:_emit_path(path, paint, force_fill)
    local verbs = path:verbs()
    if #verbs == 0 then
        return
    end
    paint = paint or Paint(Color.argb(0xFF000000))

    local k = 2 ^ (self.subpixel - 1)
    local matrix = self._matrix
    ---@param x number
    ---@return string
    local function ax(x)
        return ris((matrix.a * x + matrix.tx) * k)
    end
    ---@param y number
    ---@return string
    local function ay(y)
        return ris((matrix.d * y + matrix.ty) * k)
    end

    local parts = {}
    local cx, cy = 0, 0
    for _, verb in ipairs(verbs) do
        local op = verb[1]
        if op == Verb.MOVE_TO then
            cx, cy = verb[2], verb[3]
            parts[#parts + 1] = 'm ' .. ax(cx) .. ' ' .. ay(cy)
        elseif op == Verb.LINE_TO then
            cx, cy = verb[2], verb[3]
            parts[#parts + 1] = 'l ' .. ax(cx) .. ' ' .. ay(cy)
        elseif op == Verb.QUAD_TO then
            local qx, qy, ex, ey = verb[2], verb[3], verb[4], verb[5]
            local c1x, c1y = cx + 2 / 3 * (qx - cx), cy + 2 / 3 * (qy - cy)
            local c2x, c2y = ex + 2 / 3 * (qx - ex), ey + 2 / 3 * (qy - ey)
            parts[#parts + 1] = format('b %s %s %s %s %s %s',
                ax(c1x), ay(c1y), ax(c2x), ay(c2y), ax(ex), ay(ey))
            cx, cy = ex, ey
        elseif op == Verb.CUBIC_TO then
            parts[#parts + 1] = format('b %s %s %s %s %s %s',
                ax(verb[2]), ay(verb[3]), ax(verb[4]), ay(verb[5]), ax(verb[6]), ay(verb[7]))
            cx, cy = verb[6], verb[7]
        elseif op == Verb.CLOSE then
            parts[#parts + 1] = 'c'
        end
    end

    self:_push(format('{\\pos(0,0)\\rDefault\\an7\\blur0%s%s}{\\p%d}%s{\\p0}',
        paint_tags(paint, force_fill), self:_clip_tag(), self.subpixel, concat(parts, ' ')))
end

function AssCanvas:draw_rect(rect, paint)
    self:_emit_path(Path():add_rect(rect), paint)
end

function AssCanvas:draw_rrect(rect, radius, paint)
    self:_emit_path(Path():add_rrect(rect, radius), paint)
end

function AssCanvas:draw_path(path, paint)
    self:_emit_path(path, paint)
end

function AssCanvas:draw_line(from, to, paint)
    paint = paint or Paint(Color.argb(0xFF000000))
    local dx, dy = to.x - from.x, to.y - from.y
    local len = sqrt(dx * dx + dy * dy)
    if len == 0 then
        return
    end
    local half = (paint.stroke_width or 1) / 2
    local nx, ny = -dy / len * half, dx / len * half
    local quad = Path()
        :move_to(from.x + nx, from.y + ny)
        :line_to(to.x + nx, to.y + ny)
        :line_to(to.x - nx, to.y - ny)
        :line_to(from.x - nx, from.y - ny)
        :close()
    self:_emit_path(quad, paint, true)
end

--== content ==============================================================

---@param paragraph Paragraph
---@param position Offset
---@param text_paint TextPaint?
function AssCanvas:draw_text(paragraph, position, text_paint)
    local style = paragraph.style
    text_paint = text_paint_mod.resolve(text_paint)
    local visual_offset = text_paint.offset
    local x, y = self:_apply(position.x + visual_offset.x, position.y + visual_offset.y)
    local anchor = text_paint.anchor
    if not text_paint._anchor_explicit then
        anchor = style.align == Align.CENTER and Anchor.CENTER
            or style.align == Align.RIGHT and Anchor.CENTER_RIGHT
            or Anchor.CENTER_LEFT
    end
    local ass_anchor = ASS_ANCHORS[anchor]
    if not text_paint._anchor_explicit then
        ass_anchor = ASS_TEXT_ALIGN_ANCHORS[style.align]
    end
    if not ass_anchor then
        raise(std.ValueError('unsupported ASS text anchor: ' .. tostring(text_paint.anchor)))
    end
    local tags = {
        format(
            '{\\pos(%d,%d)\\rDefault\\an%d\\blur0\\fs%g',
            ri(x), ri(y), ass_anchor, style.font_size),
    }
    if style.font_family then
        tags[#tags + 1] = '\\fn' .. style.font_family
    end
    if style.bold then
        tags[#tags + 1] = '\\b1'
    end
    if style.italic then
        tags[#tags + 1] = '\\i1'
    end
    if style.letter_spacing ~= 0 then
        tags[#tags + 1] = format('\\fsp%g', style.letter_spacing)
    end
    tags[#tags + 1] = '\\1c&H' .. M.ass_rgb(style.color) .. '&'
    tags[#tags + 1] = '\\1a&H' .. M.ass_alpha(style.color) .. '&'
    tags[#tags + 1] = '\\bord0\\shad0'
    -- A scaled canvas (e.g. inside a FittedBox) scales glyphs with
    -- `\fscx`/`\fscy`; drawings are already scaled by `_apply`.
    if self._matrix.a ~= 1 or self._matrix.d ~= 1 then
        tags[#tags + 1] = format('\\fscx%s\\fscy%s',
            ris(self._matrix.a * 100), ris(self._matrix.d * 100))
    end
    tags[#tags + 1] = self:_clip_tag()
    tags[#tags + 1] = '}'

    local lines = {}
    -- Paragraph.line_height is a logical advance; \N uses libass font metrics.
    for i, line in ipairs(paragraph.lines) do
        lines[i] = escape_text(line)
    end
    self:_push(concat(tags) .. concat(lines, '\\N'))
end

M.AssCanvas = AssCanvas

return M

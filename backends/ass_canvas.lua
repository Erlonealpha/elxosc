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

local std = require 'elxlibs.std'
local canvas = require 'painting.canvas'
local path_mod = require 'painting.path'
local color_mod = require 'foundation.color'
local paint_mod = require 'painting.paint'

local Canvas = canvas.Canvas
local Path = path_mod.Path
local Verb = path_mod.Verb
local Color = color_mod.Color
local Paint = paint_mod.Paint
local math = math
local floor = math.floor
local sqrt = math.sqrt
local format = string.format
local concat = table.concat
local ipairs = ipairs

---@class elxasscanvas
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
local function ri(value)
    return format('%d', floor(value + 0.5))
end

---@param paint_ Paint
---@param force_fill boolean?
---@return string
local function paint_tags(paint_, force_fill)
    local rgb = M.ass_rgb(paint_.color)
    local alpha = M.ass_alpha(paint_.color)
    if paint_.style == 'stroke' and not force_fill then
        return format('\\bord%g\\shad0\\3c&H%s&\\3a&H%s&\\1c&H%s&\\1a&HFF',
            paint_.stroke_width, rgb, alpha, rgb)
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
---@overload fun(subpixel: integer?): AssCanvas
local AssCanvas = std.class.new('AssCanvas', { Canvas })

function AssCanvas:__init(subpixel)
    self.events = {}
    self.subpixel = subpixel or 4
    self._stack = {}
    self._tx, self._ty = 0, 0
    self._sx, self._sy = 1, 1
    self._clip = nil
end

--- Drop everything produced so far (start of a frame).
function AssCanvas:reset()
    self.events = {}
    self._stack = {}
    self._tx, self._ty = 0, 0
    self._sx, self._sy = 1, 1
    self._clip = nil
end

---@return string the `ass-events` payload (one line per event)
function AssCanvas:text()
    return concat(self.events, '\n')
end

---@param text string
function AssCanvas:_push(text)
    self.events[#self.events + 1] = text
end

---@param x number
---@param y number
---@return number
---@return number
function AssCanvas:_apply(x, y)
    return x * self._sx + self._tx, y * self._sy + self._ty
end

--== state ================================================================

function AssCanvas:save()
    local stack = self._stack
    stack[#stack + 1] = { self._tx, self._ty, self._sx, self._sy, self._clip }
end

function AssCanvas:restore()
    local frame = table.remove(self._stack)
    if frame then
        self._tx, self._ty, self._sx, self._sy, self._clip =
            frame[1], frame[2], frame[3], frame[4], frame[5]
    end
end

function AssCanvas:translate(dx, dy)
    self._tx = self._tx + dx
    self._ty = self._ty + dy
end

function AssCanvas:scale(sx, sy)
    self._sx = self._sx * sx
    self._sy = self._sy * (sy or sx)
end

function AssCanvas:clip_rect(rect)
    local x0, y0 = self:_apply(rect.left, rect.top)
    local x1, y1 = self:_apply(rect.right, rect.bottom)
    self._clip = format('\\clip(%s,%s,%s,%s)', ri(x0), ri(y0), ri(x1), ri(y1))
end

--== primitives ===========================================================

---@param path Path
---@param paint_ Paint?
---@param force_fill boolean?
function AssCanvas:_emit_path(path, paint_, force_fill)
    local verbs = path:verbs()
    if #verbs == 0 then
        return
    end
    paint_ = paint_ or Paint(Color.argb(0xFF000000))

    local k = 2 ^ (self.subpixel - 1)
    local sx, sy, tx, ty = self._sx, self._sy, self._tx, self._ty
    ---@param x number
    ---@return string
    local function ax(x)
        return ri((x * sx + tx) * k)
    end
    ---@param y number
    ---@return string
    local function ay(y)
        return ri((y * sy + ty) * k)
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
        paint_tags(paint_, force_fill), self._clip or '', self.subpixel, concat(parts, ' ')))
end

function AssCanvas:draw_rect(rect, paint_)
    self:_emit_path(Path():add_rect(rect), paint_)
end

function AssCanvas:draw_rrect(rect, radius, paint_)
    self:_emit_path(Path():add_rrect(rect, radius), paint_)
end

function AssCanvas:draw_path(path, paint_)
    self:_emit_path(path, paint_)
end

function AssCanvas:draw_line(from, to, paint_)
    paint_ = paint_ or Paint(Color.argb(0xFF000000))
    local dx, dy = to.x - from.x, to.y - from.y
    local len = sqrt(dx * dx + dy * dy)
    if len == 0 then
        return
    end
    local half = (paint_.stroke_width or 1) / 2
    local nx, ny = -dy / len * half, dx / len * half
    local quad = Path()
        :move_to(from.x + nx, from.y + ny)
        :line_to(to.x + nx, to.y + ny)
        :line_to(to.x - nx, to.y - ny)
        :line_to(from.x - nx, from.y - ny)
        :close()
    self:_emit_path(quad, paint_, true)
end

--== content ==============================================================

function AssCanvas:draw_text(paragraph, offset)
    local style = paragraph.style
    local x, y = self:_apply(offset.x, offset.y)
    local tags = {
        '{\\pos(', ri(x), ',', ri(y), ')\\rDefault\\an7\\blur0',
        format('\\fs%g', style.font_size),
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
    if self._clip then
        tags[#tags + 1] = self._clip
    end
    tags[#tags + 1] = '}'

    local lines = {}
    for i, line in ipairs(paragraph.lines) do
        lines[i] = escape_text(line)
    end
    self:_push(concat(tags) .. concat(lines, '\\N'))
end

M.AssCanvas = AssCanvas

return M

-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Describes *how* a shape is filled or stroked (Flutter's `Paint`).
--
-- A Paint is a plain value object: render objects build one and hand it to
-- `Canvas:draw_*`. It carries no backend specific state, so the same Paint is
-- valid for the ASS backend, a mpv.net surface or an offline recording canvas.

local std = require 'elxlibs.std'
local color = require 'foundation.color'

local Color = color.Color

---@class elxpaint
local M = {}

---@alias PaintStyle "fill" | "stroke"
---@alias StrokeCap "butt" | "round" | "square"
---@alias StrokeJoin "miter" | "round" | "bevel"

M.Style = {
    FILL = 'fill',
    STROKE = 'stroke',
}

M.StrokeCap = {
    BUTT = 'butt',
    ROUND = 'round',
    SQUARE = 'square',
}

M.StrokeJoin = {
    MITER = 'miter',
    ROUND = 'round',
    BEVEL = 'bevel',
}

---@class Paint : std.object
---@field color Color
---@field style PaintStyle
---@field stroke_width number only used when `style == 'stroke'`
---@field stroke_cap StrokeCap
---@field stroke_join StrokeJoin
---@field antialias boolean hint for backends that support it
---@overload fun(color: Color?, style: PaintStyle?, stroke_width: number?): Paint
local Paint = std.class.new('Paint')

function Paint:__init(color_, style, stroke_width)
    self.color = color_ or Color.argb(0xFF000000)
    self.style = style or M.Style.FILL
    self.stroke_width = stroke_width or 1
    self.stroke_cap = M.StrokeCap.BUTT
    self.stroke_join = M.StrokeJoin.MITER
    self.antialias = true
end

function Paint:__tostring()
    return string.format('Paint(%s, %s)', self.style, tostring(self.color))
end

---@return Paint
function Paint:copy()
    local c = Paint(self.color, self.style, self.stroke_width)
    c.stroke_cap = self.stroke_cap
    c.stroke_join = self.stroke_join
    c.antialias = self.antialias
    return c
end

M.Paint = Paint

return M

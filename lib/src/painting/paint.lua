-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Describes *how* a shape is filled or stroked (Flutter's `Paint`).
--
-- A Paint is a plain value object: render objects build one and hand it to
-- `Canvas:draw_*`. It carries no backend specific state, so the same Paint is
-- valid for the ASS backend, a mpv.net surface or an offline recording canvas.

---@namespace elxosc
---@using elxosc

local dataclass = require 'elxlibs.dataclass'
local color = require 'src.foundation.color'

local Color = color.Color

---@class mod.src.painting.paint
local M = {}

---@alias PaintStyle
--- | 'fill'
--- | 'stroke'
---@alias StrokeCap
--- | 'butt'
--- | 'round'
--- | 'square'
---@alias StrokeJoin
--- | 'miter'
--- | 'round'
--- | 'bevel'

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

---@class Paint : dataclass.Object
---@field color Color
---@field style PaintStyle
---@field stroke_width number only used when `style == 'stroke'`
---@field stroke_cap StrokeCap
---@field stroke_join StrokeJoin
---@field antialias boolean hint for backends that support it
---@field blur_radius number non-negative backend-neutral blur intent
---@overload fun(color: Color?, style: PaintStyle?, stroke_width: number?): self
local Paint = dataclass.new('Paint', nil, { eq = false, repr = false })({
    dataclass.field('color', nil),
    dataclass.field('style', M.Style.FILL),
    dataclass.field('stroke_width', 1),
    dataclass.field('stroke_cap', M.StrokeCap.BUTT),
    dataclass.field('stroke_join', M.StrokeJoin.MITER),
    dataclass.field('antialias', true),
    dataclass.field('blur_radius', 0),
})

function Paint:__init(color_, style, stroke_width)
    self.color = color_ or Color.argb(0xFF000000)
    self.style = style or M.Style.FILL
    self.stroke_width = stroke_width or 1
    self.stroke_cap = M.StrokeCap.BUTT
    self.stroke_join = M.StrokeJoin.MITER
    self.antialias = true
    self.blur_radius = 0
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
    c.blur_radius = self.blur_radius
    return c
end

dataclass.finish(Paint)

M.Paint = Paint

return M
